class FetchTournamentEventsService
  require "net/http"
  require "uri"
  require "json"

  attr_reader :tournament, :user, :error_messages

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
                    participants {
                      user {
                        id
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
                  participants {
                    user {
                      id
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
              participants {
                user {
                  id
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
      # Try the standard query first
      result = fetch_with_standard_query

      # If that fails due to complexity, try the fallback approach
      if !result && @error_messages.any? { |msg| msg.include?("complexity is too high") }
        Rails.logger.info "Query complexity too high, trying alternative approach for tournament #{tournament.id}"
        @error_messages.clear
        result = fetch_with_fallback_approach
      end

      result
    rescue => e
      Rails.logger.error "Critical error in FetchTournamentEventsService for tournament #{tournament.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      @error_messages << "A critical error occurred: #{e.message}"
      false
    end
  end

  private

  def fetch_with_standard_query
    # Make a direct HTTP request to the StartGG API
    uri = URI.parse("https://api.start.gg/gql/alpha")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

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

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error "HTTP request failed: #{response.code} #{response.message}"
      @error_messages << "API request failed with status #{response.code}"
      return false
    end

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
        api_event["sets"]["nodes"].each do |api_match|
          next unless api_match && api_match["id"]

          match = process_match(event, api_match)
          matches_synced_count += 1 if match.persisted?
        end
      end
    end

    Rails.logger.info "Successfully synced #{events_synced_count} events and #{matches_synced_count} matches for tournament #{tournament.id} (#{tournament.name})"
    true
  end

  def fetch_with_fallback_approach
    # First, fetch just the tournament and events data (no sets/standings)
    uri = URI.parse("https://api.start.gg/gql/alpha")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.path)
    request["Content-Type"] = "application/json"
    request["Authorization"] = "Bearer #{user.startgg_access_token}"

    variables = {
      tournamentId: tournament.startgg_id
    }

    request.body = {
      query: TOURNAMENT_SIMPLE_QUERY,
      variables: variables
    }.to_json

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error "HTTP request failed: #{response.code} #{response.message}"
      @error_messages << "API request failed with status #{response.code}"
      return false
    end

    data = JSON.parse(response.body)

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

    # Process each event
    events.each do |api_event|
      next unless api_event && api_event["id"]

      event = process_event(api_event)
      events_synced_count += 1 if event.persisted?

      # Now fetch sets and standings for this event with pagination
      if event.persisted?
        page = 1
        total_pages = 1 # Start with 1, will be updated after first query

        while page <= total_pages
          event_data = fetch_event_sets(event.startgg_id, page)

          if event_data
            # Update total pages from the response
            total_pages = event_data.dig("sets", "pageInfo", "totalPages") || 1

            # Process user's standing in this event (only on first page)
            if page == 1 && event_data["standings"]
              process_user_standing(event, event_data["standings"])
            end

            # Process matches
            if event_data["sets"] && event_data["sets"]["nodes"]
              event_data["sets"]["nodes"].each do |api_match|
                next unless api_match && api_match["id"]

                match = process_match(event, api_match)
                matches_synced_count += 1 if match.persisted?
              end
            end
          else
            break # Stop if there was an error
          end

          page += 1
        end
      end
    end

    Rails.logger.info "Successfully synced #{events_synced_count} events and #{matches_synced_count} matches for tournament #{tournament.id} (#{tournament.name})"
    true
  end

  def fetch_event_sets(event_id, page)
    uri = URI.parse("https://api.start.gg/gql/alpha")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.path)
    request["Content-Type"] = "application/json"
    request["Authorization"] = "Bearer #{user.startgg_access_token}"

    variables = {
      eventId: event_id,
      userId: user.uid.to_i,
      page: page
    }

    request.body = {
      query: EVENT_SETS_QUERY,
      variables: variables
    }.to_json

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error "HTTP request failed for event #{event_id}: #{response.code} #{response.message}"
      return nil
    end

    data = JSON.parse(response.body)

    if data["errors"]
      data["errors"].each do |error|
        Rails.logger.error "GraphQL Error for event #{event_id}: #{error["message"]}"
      end
      return nil
    end

    data.dig("data", "event")
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

    api_match["slots"].each_with_index do |slot, index|
      next unless slot["standing"] && slot["standing"]["entrant"] && slot["standing"]["entrant"]["participants"]

      # Check if any participant in this slot is our user
      is_user_slot = slot["standing"]["entrant"]["participants"].any? do |participant|
        participant["user"] && participant["user"]["id"] && participant["user"]["id"].to_s == user.uid.to_s
      end

      next unless is_user_slot

      # Create user match participation
      is_winner = match.winner_id.to_s == slot["standing"]["entrant"]["id"].to_s

      participation = UserMatchParticipation.find_or_initialize_by(user: user, match: match)
      participation.is_winner = is_winner

      unless participation.save
        errors = participation.errors.full_messages.join(", ")
        Rails.logger.error "Failed to save user match participation for match #{match.id}: #{errors}"
        @error_messages << "Failed to save match participation: #{errors}"
      end
    end
  end
end
