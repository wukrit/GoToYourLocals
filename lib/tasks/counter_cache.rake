namespace :counter_cache do
  desc "Reset counter cache values for all models"
  task reset: :environment do
    puts "Resetting counter caches..."

    # Reset events_count for users
    User.find_each do |user|
      User.reset_counters(user.id, :events)
      print "."
    end
    puts " Users done!"

    # Reset events_count for tournaments
    Tournament.find_each do |tournament|
      Tournament.reset_counters(tournament.id, :events)
      print "."
    end
    puts " Tournaments done!"

    # Reset matches_count for events
    Event.find_each do |event|
      Event.reset_counters(event.id, :matches)
      print "."
    end
    puts " Events done!"

    puts "All counter caches have been reset!"
  end
end