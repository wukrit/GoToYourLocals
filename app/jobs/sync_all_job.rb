class SyncAllJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)

    # First sync tournaments
    tournaments_service = FetchUserTournamentsService.new(user)
    tournaments_success = tournaments_service.call

    # Then sync events for all tournaments
    events_success = true
    events_errors = []

    if tournaments_success
      user.tournaments.each do |tournament|
        events_service = FetchTournamentEventsService.new(tournament, user)
        unless events_service.call
          events_success = false
          events_errors += events_service.error_messages
        end
      end
    end

    # Set appropriate flash messages for the user to see next time they load a page
    if tournaments_success && events_success
      message = "Successfully synced all tournaments, events, and matches."
      user.update(last_sync_message: message, last_sync_status: "success")
    elsif tournaments_success
      message = "Synced tournaments, but some events failed: #{events_errors.uniq.join(", ")}"
      user.update(last_sync_message: message, last_sync_status: "warning")
    else
      message = "Failed to sync tournaments: #{tournaments_service.error_messages.join(", ")}"
      user.update(last_sync_message: message, last_sync_status: "error")
    end
  end
end
