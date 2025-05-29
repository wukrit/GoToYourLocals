class HomeController < ApplicationController
  before_action :authenticate_user!, only: [:sync_tournaments, :sync_tournament_events, :sync_all]
  helper_method :filter_events_by_game

  def index
    if user_signed_in?
      # Extract normalized game names
      @games = helpers.extract_game_names(current_user.events)

      # Get selected game or default to first game
      @selected_game = params[:game].presence || @games.first
    end
  end

  def sync_tournaments
    service = FetchUserTournamentsService.new(current_user)
    success = service.call

    if success
      flash[:notice] = "Successfully synced your tournaments."
    else
      flash[:alert] = "Failed to sync tournaments: #{service.error_messages.join(", ")}"
    end

    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: turbo_stream.replace("user_data",
          partial: "user_data",
          locals: {
            games: helpers.extract_game_names(current_user.events),
            selected_game: helpers.extract_game_names(current_user.events).first
          })
      }
      format.html { redirect_to root_path }
    end
  end

  def sync_tournament_events
    tournament = Tournament.find(params[:tournament_id])
    service = FetchTournamentEventsService.new(tournament, current_user)

    if service.call
      flash[:notice] = "Successfully synced events and matches for tournament #{tournament.name}."
    else
      flash[:alert] = "Failed to sync events and matches: #{service.error_messages.join(", ")}"
    end

    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: turbo_stream.replace("user_data",
          partial: "user_data",
          locals: {
            games: helpers.extract_game_names(current_user.events),
            selected_game: helpers.extract_game_names(current_user.events).first
          })
      }
      format.html { redirect_to root_path }
    end
  end

  def sync_all
    # First sync tournaments
    tournaments_service = FetchUserTournamentsService.new(current_user)
    tournaments_success = tournaments_service.call

    # Then sync events for all tournaments
    events_success = true
    events_errors = []

    if tournaments_success
      current_user.tournaments.each do |tournament|
        events_service = FetchTournamentEventsService.new(tournament, current_user)
        unless events_service.call
          events_success = false
          events_errors += events_service.error_messages
        end
      end
    end

    if tournaments_success && events_success
      flash[:notice] = "Successfully synced all tournaments, events, and matches."
    elsif tournaments_success
      flash[:alert] = "Synced tournaments, but some events failed: #{events_errors.uniq.join(", ")}"
    else
      flash[:alert] = "Failed to sync tournaments: #{tournaments_service.error_messages.join(", ")}"
    end

    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: turbo_stream.replace("user_data",
          partial: "user_data",
          locals: {
            games: helpers.extract_game_names(current_user.events),
            selected_game: helpers.extract_game_names(current_user.events).first
          })
      }
      format.html { redirect_to root_path }
    end
  end

  # Helper method to filter events by normalized game name
  def filter_events_by_game(events, game_name)
    events.select do |event|
      helpers.normalize_game_name(event.name) == game_name
    end
  end
end
