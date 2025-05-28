require "omniauth-oauth2"

module OmniAuth
  module Strategies
    class Startgg < OmniAuth::Strategies::OAuth2
      option :name, :startgg

      option :client_options, {
        site: "https://api.start.gg",
        authorize_url: "https://start.gg/oauth/authorize",
        token_url: "https://api.start.gg/oauth/token"
      }

      uid { raw_info["id"] }

      info do
        {
          name: raw_info["name"],
          email: raw_info["email"]
          # Add other user info fields as needed from Start.gg
        }
      end

      extra do
        {
          "raw_info" => raw_info
        }
      end

      def raw_info
        @raw_info ||= access_token.get("/currentUser").parsed
        # You might need to adjust the endpoint and parsing based on Start.gg's API
      end

      # Override the callback_url to ensure it's correctly constructed
      def callback_url
        full_host + script_name + callback_path
      end
    end
  end
end
