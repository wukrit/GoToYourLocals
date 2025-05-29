namespace :debug do
  desc "Debug match syncing for a specific tournament"
  task :matches, [:tournament_id] => :environment do |t, args|
    tournament_id = args[:tournament_id] || Tournament.last.id
    tournament = Tournament.find(tournament_id)
    user = User.first

    puts "Debugging matches for tournament: #{tournament.name} (ID: #{tournament.id})"
    puts "User: #{user.tag} (ID: #{user.id}, UID: #{user.uid})"

    # Direct API call to get tournament data
    uri = URI.parse("https://api.start.gg/gql/alpha")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.path)
    request["Content-Type"] = "application/json"
    request["Authorization"] = "Bearer #{user.startgg_access_token}"

    # First, check if this user has any sets in the system at all
    user_sets_query = <<-GRAPHQL
      query UserSets($userId: ID!) {
        user(id: $userId) {
          id
          player {
            id
            gamerTag
            sets(page: 1, perPage: 10) {
              nodes {
                id
                event {
                  id
                  name
                  tournament {
                    id
                    name
                  }
                }
                fullRoundText
                displayScore
                winnerId
                slots {
                  standing {
                    entrant {
                      id
                      name
                      participants {
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

    user_variables = {
      userId: user.uid.to_i
    }

    request.body = {
      query: user_sets_query,
      variables: user_variables
    }.to_json

    response = http.request(request)

    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)

      if data["errors"]
        puts "GraphQL Errors:"
        data["errors"].each do |error|
          puts "- #{error["message"]}"
        end
      else
        user_data = data.dig("data", "user")
        if user_data && user_data["player"]
          puts "Found player with gamer tag: #{user_data["player"]["gamerTag"]}"

          sets = user_data.dig("player", "sets", "nodes")
          if sets&.any?
            puts "\nFound #{sets.size} sets for user:"

            sets.each do |set|
              event = set["event"]
              tournament = event&.dig("tournament")

              puts "  Match ID: #{set["id"]}"
              puts "  Tournament: #{tournament ? tournament["name"] : "Unknown"}"
              puts "  Event: #{event ? event["name"] : "Unknown"}"
              puts "  Round: #{set["fullRoundText"]}"
              puts "  Score: #{set["displayScore"]}"
              puts "  Winner ID: #{set["winnerId"]}"

              if set["slots"]&.any?
                puts "  Players:"
                set["slots"].each do |slot|
                  if slot["standing"] && slot["standing"]["entrant"]
                    entrant = slot["standing"]["entrant"]
                    is_winner = set["winnerId"].to_s == entrant["id"].to_s

                    puts "    #{entrant["name"]} (#{is_winner ? "Winner" : "Loser"})"

                    entrant["participants"]&.each do |participant|
                      if participant["player"]
                        puts "      Player: #{participant["player"]["gamerTag"]} (ID: #{participant["player"]["id"]})"
                      end
                    end
                  end
                end
              end
              puts "  ------------------------"
            end
          else
            puts "No sets found for this user."
          end
        else
          puts "No player data found for user ID: #{user.uid}"
        end
      end
    else
      puts "HTTP request failed: #{response.code} #{response.message}"
    end
  end
end