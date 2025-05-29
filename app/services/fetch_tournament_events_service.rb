class FetchTournamentEventsService
  require "net/http"
  require "uri"
  require "json"

  attr_reader :tournament, :user, :error_messages

  # Start.gg API limits: 80 requests per 60 seconds
  MAX_REQUESTS_PER_MINUTE = 80
  RATE_LIMIT_WINDOW = 60 # seconds

  # Class variable to track API requests across instances
  @@request_timestamps = []
  @@request_mutex = Mutex.new

  # Define the query as a plain string, based on the Start.gg schema
  TOURNAMENT_EVENTS_QUERY = <<-GRAPHQL
    query TournamentEvents($tournamentId: ID!, $userId: ID!) {
      tournament(id: $tournamentId) {
        id
        name
        events {
          id
          name
          slug
          numEntrants
          standings(query: {
            page: 1,
            perPage: 100
          }) {
            nodes {
              placement
              entrant {
                id
                participants {
                  user {
                    id
                  }
                  player {
                    gamerTag
                  }
                }
              }
            }
          }
          sets(
            filters: {
              participantIds: [$userId]
            }
            page: 1
            perPage: 50
          ) {
            nodes {
              id
              round
              fullRoundText
              displayScore
              identifier
              slots {
                standing {
                  placement
                  entrant {
                    id
                    name
                    participants {
                      user {
                        id
                      }
                      player {
                        gamerTag
                      }
                    }
                  }
                }
              }
              winnerId
            }
          }
        }
      }
    }
  GRAPHQL

  # Alternative approach: get user's sets directly
  USER_SETS_QUERY = <<-GRAPHQL
    query UserSets($userId: ID!, $perPage: Int!, $page: Int!) {
      user(id: $userId) {
        player {
          sets(
            perPage: $perPage,
            page: $page
          ) {
            pageInfo {
              totalPages
              page
            }
            nodes {
              id
              fullRoundText
              displayScore
              round
              winnerId
              event {
                id
                name
                videogame {
                  id
                  name
                }
                tournament {
                  id
                  name
                }
              }
              slots {
                standing {
                  placement
                  entrant {
                    id
                    name
                    participants {
                      user {
                        id
                      }
                      player {
                        id
                        gamerTag
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  GRAPHQL

  # Alternative query for very large tournaments
  TOURNAMENT_SIMPLE_QUERY = <<-GRAPHQL
    query TournamentSimple($tournamentId: ID!) {
      tournament(id: $tournamentId) {
        id
        name
        events {
          id
          name
          slug
          numEntrants
        }
      }
    }
  GRAPHQL

  # Query for just a single event's sets
  EVENT_SETS_QUERY = <<-GRAPHQL
    query EventSets($eventId: ID!, $userId: ID!, $page: Int!) {
      event(id: $eventId) {
        id
        sets(
          filters: {
            participantIds: [$userId]
          }
          page: $page
          perPage: 50
        ) {
          pageInfo {
            totalPages
            page
          }
          nodes {
            id
            round
            fullRoundText
            displayScore
            identifier
            slots {
              standing {
                placement
                entrant {
                  id
                  name
                  participants {
                    user {
                      id
                    }
                    player {
                      gamerTag
                    }
                  }
                }
              }
            }
            winnerId
          }
        }
        standings(query: {
          page: 1,
          perPage: 100
        }) {
          nodes {
            placement
            entrant {
              id
              name
              participants {
                user {
                  id
                }
                player {
                  gamerTag
                }
              }
            }
          }
        }
      }
    }
  GRAPHQL

  def initialize(tournament, user)
    @tournament = tournament
    @user = user
    @error_messages = []
  end

  def call
    unless tournament.startgg_id
      Rails.logger.error "Tournament #{tournament.id} (#{tournament.name}) is missing StartGG ID."
      @error_messages << "Tournament details are missing."
      return false
    end

    unless user.uid && user.startgg_access_token
      Rails.logger.error "User #{user.id} (UID: #{user.uid}) is missing StartGG UID or access token."
      @error_messages << "User authentication details for StartGG are missing."
      return false
    end

    Rails.logger.debug "Starting event sync for tournament #{tournament.id} (#{tournament.name}) and user #{user.id}"

    begin
      # First, sync the event standings to get placement info
      result = fetch_with_standard_query

      # Next, fetch all the user's sets directly for better match data
      result = fetch_user_sets(tournament) && result

      result
    rescue => e
      Rails.logger.error "Critical error in FetchTournamentEventsService for tournament #{tournament.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      @error_messages << "A critical error occurred: #{e.message}"
      false
    end
  end

  private

  # Method to handle rate limiting
  def respect_rate_limit
    @@request_mutex.synchronize do
      current_time = Time.now.to_i

      # Remove timestamps older than our window
      @@request_timestamps.reject! { |timestamp| timestamp < current_time - RATE_LIMIT_WINDOW }

      # If we've made too many requests, wait
      if @@request_timestamps.size >= MAX_REQUESTS_PER_MINUTE
        oldest_timestamp = @@request_timestamps.min
        wait_time = (RATE_LIMIT_WINDOW - (current_time - oldest_timestamp)) + 1

        if wait_time > 0
          Rails.logger.info "Rate limit approaching, waiting #{wait_time} seconds before next request"
          sleep(wait_time)
        end
      end

      # Add current request timestamp
      @@request_timestamps << Time.now.to_i
    end
  end

  # Method to make a rate-limited API request with retries
  def make_api_request(uri, request)
    max_retries = 3
    retry_count = 0

    while retry_count < max_retries
      respect_rate_limit

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 30

      begin
        response = http.request(request)

        case response.code.to_i
        when 200
          return response
        when 429
          retry_count += 1
          wait_time = 10 + (retry_count * 5) # Progressive backoff
          Rails.logger.warn "Rate limit exceeded (429). Retry #{retry_count}/#{max_retries}. Waiting #{wait_time} seconds."
          sleep(wait_time)
        when 500..599
          retry_count += 1
          wait_time = 3 + (retry_count * 2)
          Rails.logger.warn "Server error (#{response.code}). Retry #{retry_count}/#{max_retries}. Waiting #{wait_time} seconds."
          sleep(wait_time)
        else
          Rails.logger.error "HTTP request failed: #{response.code} #{response.message}"
          @error_messages << "API request failed with status #{response.code}"
          return response
        end
      rescue Net::ReadTimeout, Net::OpenTimeout => e
        retry_count += 1
        wait_time = 5 + (retry_count * 3)
        Rails.logger.warn "Request timeout: #{e.message}. Retry #{retry_count}/#{max_retries}. Waiting #{wait_time} seconds."
        sleep(wait_time)
      rescue => e
        Rails.logger.error "Request error: #{e.message}"
        @error_messages << "API request error: #{e.message}"
        return nil
      end
    end

    Rails.logger.error "Failed after #{max_retries} retries"
    @error_messages << "API request failed after #{max_retries} retries"
    nil
  end

  def fetch_with_standard_query
    # Make a direct HTTP request to the StartGG API
    uri = URI.parse("https://api.start.gg/gql/alpha")

    request = Net::HTTP::Post.new(uri.path)
    request["Content-Type"] = "application/json"
    request["Authorization"] = "Bearer #{user.startgg_access_token}"

    variables = {
      tournamentId: tournament.startgg_id,
      userId: user.uid.to_i
    }

    request.body = {
      query: TOURNAMENT_EVENTS_QUERY,
      variables: variables
    }.to_json

    response = make_api_request(uri, request)
    return false unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    Rails.logger.debug "StartGG API Response Data: #{data.inspect}"

    if data["errors"]
      data["errors"].each do |error|
        @error_messages << "GraphQL Error: #{error["message"]}"
      end
      Rails.logger.error "GraphQL query failed for tournament #{tournament.id}: #{@error_messages.join("; ")}"
      return false
    end

    tournament_data = data.dig("data", "tournament")
    if tournament_data.nil?
      Rails.logger.warn "No tournament data returned from StartGG API for ID: #{tournament.startgg_id}. Raw response: #{data.inspect}"
      return false
    end

    events = tournament_data["events"]
    unless events&.any?
      Rails.logger.info "No events found for tournament #{tournament.id} (#{tournament.name})."
      return true # Not an error, just no events
    end

    events_synced_count = 0
    matches_synced_count = 0

    events.each do |api_event|
      next unless api_event && api_event["id"]

      event = process_event(api_event)
      events_synced_count += 1 if event.persisted?

      # Process user's standing in this event
      process_user_standing(event, api_event["standings"]) if event.persisted?

      # Process user's matches in this event
      if api_event["sets"] && api_event["sets"]["nodes"]
        Rails.logger.info "Found #{api_event["sets"]["nodes"].size} matches for event #{event.name}"

        api_event["sets"]["nodes"].each do |api_match|
          next unless api_match && api_match["id"]

          # Debug output to check match structure
          Rails.logger.debug "Processing match: #{api_match.inspect}"

          match = process_match(event, api_match)
          matches_synced_count += 1 if match.persisted?
        end
      else
        Rails.logger.info "No matches found for event #{event.name}"
      end
    end

    Rails.logger.info "Successfully synced #{events_synced_count} events and #{matches_synced_count} matches for tournament #{tournament.id} (#{tournament.name})"
    true
  end

  def fetch_user_sets(target_tournament)
    Rails.logger.info "Fetching user sets for tournament #{target_tournament.id} (#{target_tournament.name})"

    uri = URI.parse("https://api.start.gg/gql/alpha")
    page = 1
    per_page = 50
    total_pages = 1
    matches_synced_count = 0

    # Process up to 10 pages of sets maximum (500 sets)
    max_pages = 10

    while page <= [total_pages, max_pages].min
      request = Net::HTTP::Post.new(uri.path)
      request["Content-Type"] = "application/json"
      request["Authorization"] = "Bearer #{user.startgg_access_token}"

      variables = {
        userId: user.uid.to_i,
        perPage: per_page,
        page: page
      }

      request.body = {
        query: USER_SETS_QUERY,
        variables: variables
      }.to_json

      response = make_api_request(uri, request)
      return false unless response.is_a?(Net::HTTPSuccess)

      data = JSON.parse(response.body)

      if data["errors"]
        data["errors"].each do |error|
          @error_messages << "GraphQL Error: #{error["message"]}"
        end
        Rails.logger.error "GraphQL query failed for user sets: #{@error_messages.join("; ")}"
        return false
      end

      player_data = data.dig("data", "user", "player")

      if player_data.nil?
        Rails.logger.warn "No player data returned from StartGG API for user #{user.uid}"
        return false
      end

      sets_data = player_data["sets"]

      # Update total pages from API response
      total_pages = sets_data.dig("pageInfo", "totalPages") || 1

      sets = sets_data["nodes"] || []
      Rails.logger.info "Processing #{sets.size} sets from page #{page}/#{total_pages}"

      # Filter for sets from the target tournament
      tournament_sets = sets.select do |set|
        tournament_id = set.dig("event", "tournament", "id")&.to_i
        tournament_id == target_tournament.startgg_id
      end

      Rails.logger.info "Found #{tournament_sets.size} sets for tournament #{target_tournament.name}"

      # Process each set
      tournament_sets.each do |api_match|
        event_id = api_match.dig("event", "id")

        # Find or create the event
        event = Event.find_by(startgg_id: event_id)

        # Skip if we don't have this event in our database
        next unless event

        # Process the match
        match = process_match_from_set(event, api_match)
        matches_synced_count += 1 if match.persisted?
      end

      page += 1
    end

    Rails.logger.info "Successfully synced #{matches_synced_count} matches for tournament #{target_tournament.id} (#{target_tournament.name})"
    true
  end

  def process_match_from_set(event, api_match)
    # Create or update match
    match = Match.find_or_initialize_by(startgg_id: api_match["id"])
    match.event = event
    match.round = api_match["round"]
    match.round_number = api_match["round"].to_i if api_match["round"].present?
    match.full_round_text = api_match["fullRoundText"]
    match.display_score = api_match["displayScore"]
    match.winner_id = api_match["winnerId"]

    unless match.save
      errors = match.errors.full_messages.join(", ")
      Rails.logger.error "Failed to save match #{api_match["id"]}: #{errors}"
      @error_messages << "Failed to save match: #{errors}"
      return match
    end

    # Process participants from slots
    return match unless api_match["slots"]&.any?

    # Track all participants
    all_participants = []

    api_match["slots"].each do |slot|
      next unless slot["standing"] && slot["standing"]["entrant"]

      entrant = slot["standing"]["entrant"]
      entrant_id = entrant["id"]
      entrant_name = entrant["name"]
      is_winner = match.winner_id.to_s == entrant_id.to_s

      entrant["participants"]&.each do |participant|
        next unless participant["user"] && participant["user"]["id"]

        user_id = participant["user"]["id"].to_s
        player_data = participant["player"]
        gamer_tag = player_data ? player_data["gamerTag"] : nil

        all_participants << {
          user_id: user_id,
          gamer_tag: gamer_tag || entrant_name || "Unknown Player",
          entrant_id: entrant_id,
          is_winner: is_winner
        }
      end
    end

    # Save participation for all participants
    all_participants.each do |participant_data|
      # Try to find the user in our database
      participant_user = if participant_data[:user_id] == user.uid.to_s
        user
      else
        User.find_by(uid: participant_data[:user_id])
      end

      # Create a placeholder user if needed
      if participant_user.nil?
        participant_user = User.create(
          uid: participant_data[:user_id],
          tag: participant_data[:gamer_tag],
          email: "player-#{participant_data[:user_id]}@placeholder.com"
        )
      elsif participant_user.tag.blank? && participant_data[:gamer_tag].present?
        # Update tag if we have it
        participant_user.update(tag: participant_data[:gamer_tag])
      end

      # Create participation record
      if participant_user.persisted?
        participation = UserMatchParticipation.find_or_initialize_by(
          user: participant_user,
          match: match
        )
        participation.is_winner = participant_data[:is_winner]

        unless participation.save
          errors = participation.errors.full_messages.join(", ")
          Rails.logger.error "Failed to save match participation for user #{participant_user.id}: #{errors}"
        end
      end
    end

    match
  end

  def process_event(api_event)
    event = Event.find_or_initialize_by(startgg_id: api_event["id"])
    event.tournament = tournament
    event.name = api_event["name"]
    event.slug = api_event["slug"]
    event.num_entrants = api_event["numEntrants"]

    unless event.save
      errors = event.errors.full_messages.join(", ")
      Rails.logger.error "Failed to save event #{api_event["id"]} (#{api_event["name"]}): #{errors}"
      @error_messages << "Failed to save event #{api_event["name"]}: #{errors}"
    end

    event
  end

  def process_user_standing(event, standings_data)
    return unless standings_data && standings_data["nodes"]&.any?

    # Find the user's standing
    user_standing = standings_data["nodes"].find do |standing|
      next unless standing["entrant"] && standing["entrant"]["participants"]

      # Check if any participant in this entrant is our user
      standing["entrant"]["participants"].any? do |participant|
        participant["user"] && participant["user"]["id"] && participant["user"]["id"].to_s == user.uid.to_s
      end
    end

    return unless user_standing

    # Create or update the user's participation in this event
    participation = UserEventParticipation.find_or_initialize_by(user: user, event: event)
    participation.final_placement = user_standing["placement"]
    participation.entrant_id = user_standing["entrant"]["id"] if user_standing["entrant"]

    unless participation.save
      errors = participation.errors.full_messages.join(", ")
      Rails.logger.error "Failed to save user event participation for event #{event.id} (#{event.name}): #{errors}"
      @error_messages << "Failed to save participation for event #{event.name}: #{errors}"
    end
  end

  def process_match(event, api_match)
    match = Match.find_or_initialize_by(startgg_id: api_match["id"])
    match.event = event
    match.round = api_match["round"]
    match.round_number = api_match["round"].to_i if api_match["round"].present?
    match.identifier = api_match["identifier"]
    match.full_round_text = api_match["fullRoundText"]
    match.display_score = api_match["displayScore"]
    match.winner_id = api_match["winnerId"]

    unless match.save
      errors = match.errors.full_messages.join(", ")
      Rails.logger.error "Failed to save match #{api_match["id"]}: #{errors}"
      @error_messages << "Failed to save match: #{errors}"
      return match
    end

    # Process participants in this match
    process_match_participants(match, api_match) if match.persisted?

    match
  end

  def process_match_participants(match, api_match)
    # Get the participants from the slots
    return unless api_match["slots"]&.any?

    # Track all participants for this match
    all_participants = []

    # First pass: collect all participants in this match
    api_match["slots"].each do |slot|
      next unless slot["standing"] && slot["standing"]["entrant"] && slot["standing"]["entrant"]["participants"]

      entrant_id = slot["standing"]["entrant"]["id"]
      entrant_name = slot["standing"]["entrant"]["name"]
      is_winner = match.winner_id.to_s == entrant_id.to_s

      # Process each participant in the entrant
      slot["standing"]["entrant"]["participants"].each do |participant|
        next unless participant["user"] && participant["user"]["id"]

        user_id = participant["user"]["id"].to_s
        gamer_tag = participant["player"] && participant["player"]["gamerTag"]

        # Store participant info
        all_participants << {
          user_id: user_id,
          gamer_tag: gamer_tag || entrant_name || "Unknown Player",
          entrant_id: entrant_id,
          is_winner: is_winner
        }
      end
    end

    # Find our user in the participants
    user_participant = all_participants.find { |p| p[:user_id] == user.uid.to_s }

    # Save our user's participation
    if user_participant
      participation = UserMatchParticipation.find_or_initialize_by(user: user, match: match)
      participation.is_winner = user_participant[:is_winner]

      unless participation.save
        errors = participation.errors.full_messages.join(", ")
        Rails.logger.error "Failed to save user match participation for match #{match.id}: #{errors}"
        @error_messages << "Failed to save match participation: #{errors}"
      end
    end

    # Find opponents (everyone else in the match)
    opponents = all_participants.reject { |p| p[:user_id] == user.uid.to_s }

    # Try to find or create users for opponents and create their participations
    opponents.each do |opponent|
      # Try to find the opponent in our database
      opponent_user = User.find_by(uid: opponent[:user_id])

      # If we don't have this user, create a placeholder
      if opponent_user.nil?
        opponent_user = User.create(
          uid: opponent[:user_id],
          tag: opponent[:gamer_tag],
          email: "player-#{opponent[:user_id]}@placeholder.com" # Use a placeholder email
        )
      elsif opponent_user.tag.blank? && opponent[:gamer_tag].present?
        # Update the tag if we have it now
        opponent_user.update(tag: opponent[:gamer_tag])
      end

      # Create the match participation for the opponent
      if opponent_user.persisted?
        participation = UserMatchParticipation.find_or_initialize_by(user: opponent_user, match: match)
        participation.is_winner = opponent[:is_winner]
        participation.save
      end
    end
  end
end
