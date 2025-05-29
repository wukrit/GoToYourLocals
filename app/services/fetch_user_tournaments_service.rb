class FetchUserTournamentsService
  require "net/http"
  require "uri"
  require "json"

  attr_reader :user, :error_messages

  # Define the query as a plain string
  USER_TOURNAMENTS_QUERY = <<-GRAPHQL
    query UserTournaments($startggUserId: ID!, $page: Int, $perPage: Int) {
      user(id: $startggUserId) {
        id
        tournaments(query: { page: $page, perPage: $perPage }) {
          nodes {
            id
            name
            slug
            startAt
            endAt
            isOnline
            venueName
            venueAddress
            city
            addrState
            countryCode
            images {
              type
              url
            }
          }
          pageInfo {
            page
            totalPages
          }
        }
      }
    }
  GRAPHQL

  def initialize(user)
    @user = user
    @error_messages = []
  end

  def call
    unless user.uid && user.startgg_access_token
      Rails.logger.error "User #{user.id} (UID: #{user.uid}) is missing StartGG UID or access token."
      @error_messages << "User authentication details for StartGG are missing."
      return false
    end

    Rails.logger.debug "Starting tournament sync for user #{user.id} (StartGG UID: #{user.uid})"
    page_num = 1
    per_page = 50
    tournaments_synced_count = 0

    loop do
      variables = {
        startggUserId: user.uid.to_i,
        page: page_num,
        perPage: per_page
      }

      Rails.logger.debug "Querying StartGG API with variables: #{variables.inspect}"

      begin
        # Make a direct HTTP request to the StartGG API
        uri = URI.parse("https://api.start.gg/gql/alpha")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        request = Net::HTTP::Post.new(uri.path)
        request["Content-Type"] = "application/json"
        request["Authorization"] = "Bearer #{user.startgg_access_token}"

        request.body = {
          query: USER_TOURNAMENTS_QUERY,
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
          Rails.logger.error "GraphQL query failed for user #{user.id}: #{@error_messages.join("; ")}"
          return false
        end

        user_data = data.dig("data", "user")
        if user_data.nil?
          Rails.logger.warn "No user data returned from StartGG API for UID: #{user.uid}. Raw response: #{data.inspect}"
          break
        end

        tournaments = user_data.dig("tournaments", "nodes")
        unless tournaments&.any?
          Rails.logger.info "No tournaments found on page #{page_num} for user #{user.id}."
          Rails.logger.debug "User data from API: #{user_data.inspect}"
          if user_data.dig("tournaments", "pageInfo")
            Rails.logger.debug "PageInfo from API: #{user_data.dig("tournaments", "pageInfo").inspect}"
          else
            Rails.logger.debug "No tournaments or pageInfo in response: #{user_data.dig("tournaments").inspect}"
          end
          break
        end

        Rails.logger.debug "Processing #{tournaments.size} tournaments from page #{page_num}."
        tournaments.each do |api_tournament|
          process_tournament(api_tournament)
          tournaments_synced_count += 1
        end

        page_info = user_data.dig("tournaments", "pageInfo")
        Rails.logger.debug "PageInfo after processing: #{page_info.inspect}"

        break unless page_info && page_info["page"] && page_info["totalPages"] && page_info["page"] < page_info["totalPages"]
        page_num += 1
        Rails.logger.debug "Moving to next page: #{page_num}"
      rescue => e
        Rails.logger.error "Error fetching/processing tournaments for user #{user.id} on page #{page_num}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        @error_messages << "An unexpected error occurred: #{e.message}"
        return false
      end
    end

    Rails.logger.info "Successfully synced #{tournaments_synced_count} tournaments for user #{user.id}."
    true
  rescue => e
    Rails.logger.error "Critical error in FetchUserTournamentsService for user #{user.id}: #{e.message}"
    @error_messages << "A critical error occurred: #{e.message}"
    false
  end

  private

  def process_tournament(api_tournament)
    tournament = Tournament.find_or_initialize_by(startgg_id: api_tournament["id"])
    tournament.name = api_tournament["name"]
    tournament.slug = api_tournament["slug"]
    tournament.start_at = Time.at(api_tournament["startAt"]) if api_tournament["startAt"].present?
    tournament.end_at = Time.at(api_tournament["endAt"]) if api_tournament["endAt"].present?
    tournament.is_online = api_tournament["isOnline"]
    tournament.venue_name = api_tournament["venueName"]

    tournament.city = api_tournament["city"]
    tournament.state = api_tournament["addrState"]
    tournament.country_code = api_tournament["countryCode"]

    tournament.images = api_tournament["images"] if api_tournament["images"].present?

    unless tournament.save
      errors = tournament.errors.full_messages.join(", ")
      Rails.logger.error "Failed to save tournament #{api_tournament["id"]} (#{api_tournament["name"]}): #{errors}"
      @error_messages << "Failed to save tournament #{api_tournament["name"]}: #{errors}"
    end

    UserTournamentParticipation.find_or_create_by(user: user, tournament: tournament) if tournament.persisted?
  end
end
