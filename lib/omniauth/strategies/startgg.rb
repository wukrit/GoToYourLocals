require "omniauth-oauth2"

module OmniAuth
  module Strategies
    class Startgg < OmniAuth::Strategies::OAuth2
      option :name, :startgg

      option :client_options, {
        site: "https://api.start.gg",
        authorize_url: "https://start.gg/oauth/authorize",
        token_url: "https://api.start.gg/oauth/access_token",
        gql_url: "https://api.start.gg/gql/alpha"
      }

      # Ensure the token request is sent as JSON
      option :token_options, [:headers, :body]

      uid do
        raw_info["id"]
      end

      info do
        player_gamertag = raw_info.dig("player", "gamerTag")
        {
          email: raw_info["email"],
          gamerTag: player_gamertag || raw_info["slug"]
          # Add other user info fields as needed from Start.gg (e.g., raw_info["gamerTag"])
        }
      end

      extra do
        {
          "raw_info" => raw_info
        }
      end

      def raw_info
        @raw_info ||= fetch_user_info
      end

      def fetch_user_info
        query = <<~GRAPHQL
          query CurrentUser {
            currentUser {
              id
              email
              slug
              player {
                gamerTag
              }
            }
          }
        GRAPHQL
        response = access_token.post(options.client_options.gql_url, {
          headers: {"Content-Type" => "application/json"},
          body: {query: query}.to_json
        }).parsed

        if response["data"] && response["data"]["currentUser"]
          response["data"]["currentUser"]
        else
          {} # Return empty hash or raise an error
        end
      end

      # Override to customize the token request
      def build_access_token
        # Parameters for the JSON body of the token request
        payload = {
          client_id: client.id,
          client_secret: client.secret,
          grant_type: "authorization_code",
          code: request.params["code"],
          redirect_uri: callback_url,
          scope: options.scope # Ensure this is a space-separated string
        }

        # Options for the OAuth2::Client#get_token call
        opts = {
          headers: {
            "Content-Type" => "application/json",
            "Accept" => "application/json" # Also explicitly accept JSON response
          },
          body: payload.to_json,
          # According to RFC6749, redirect_uri is required in the token request
          # if it was present in the authorization request. It's in our JSON body.
          # We pass it here as well, as omniauth-oauth2/oauth2 gem might do internal checks.
          redirect_uri: callback_url
        }

        # Make the token request
        # The first parameter to get_token is the authorization code.
        # The second is the hash of options.
        client.auth_code.get_token(request.params["code"], opts)

      rescue ::OAuth2::Error => e
        Rails.logger.error "Start.gg OAuth2 Token Error: #{e.message}"
        raise e
      end

      # Override the callback_url to ensure it's correctly constructed
      def callback_url
        full_host + script_name + callback_path
      end
    end
  end
end
