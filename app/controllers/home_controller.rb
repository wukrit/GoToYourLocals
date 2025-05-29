class HomeController < ApplicationController
  before_action :authenticate_user!, only: [:sync_tournaments, :sync_tournament_events, :sync_all]
  before_action :check_stuck_sync, only: [:index, :sync_tournaments, :sync_tournament_events, :sync_all], if: :user_signed_in?

  def index
    if user_signed_in?
      # Extract normalized game names - use counter cache for optimization
      @games = helpers.extract_game_names(current_user.events.includes(:tournament))

      # Get selected game or default to first game
      @selected_game = params[:game].presence || @games.first

      respond_to do |format|
        format.html
        format.turbo_stream {
          render turbo_stream: [
            turbo_stream.update("game_results",
              partial: "game_results",
              locals: {
                selected_game: @selected_game,
                date_range: params[:date_range],
                tournament_type: params[:tournament_type] || "offline"
              }
            )
          ]
        }
      end
    end
  end

  def sync_tournaments
    # Check if a sync is already in progress
    if current_user.sync_in_progress?
      flash[:alert] = "A sync is already in progress. Please wait until it completes."
    else
      # Set sync_in_progress flag immediately for UI feedback
      current_user.update(sync_in_progress: true)

      service = FetchUserTournamentsService.new(current_user)
      success = service.call

      # Update the sync status when done
      current_user.update(sync_in_progress: false)

      # Expire caches
      expire_fragment_caches

      if success
        flash[:notice] = "Successfully synced your tournaments."
      else
        flash[:alert] = "Failed to sync tournaments: #{service.error_messages.join(", ")}"
      end
    end

    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: [
          turbo_stream.update("action_panel",
            partial: "shared/action_panel",
            locals: { current_user: current_user }),
          turbo_stream.update("user_data",
            partial: "user_data",
            locals: {
              games: helpers.extract_game_names(current_user.events.includes(:tournament)),
              selected_game: helpers.extract_game_names(current_user.events.includes(:tournament)).first
            })
        ]
      }
      format.html { redirect_to root_path }
    end
  end

  def sync_tournament_events
    # Check if a sync is already in progress
    if current_user.sync_in_progress?
      flash[:alert] = "A sync is already in progress. Please wait until it completes."
    else
      # Set sync_in_progress flag immediately for UI feedback
      current_user.update(sync_in_progress: true)

      tournament = Tournament.find(params[:tournament_id])
      service = FetchTournamentEventsService.new(tournament, current_user)

      success = service.call

      # Update the sync status when done
      current_user.update(sync_in_progress: false)

      # Expire caches
      expire_fragment_caches

      if success
        flash[:notice] = "Successfully synced events and matches for tournament #{tournament.name}."
      else
        flash[:alert] = "Failed to sync events and matches: #{service.error_messages.join(", ")}"
      end
    end

    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: [
          turbo_stream.update("action_panel",
            partial: "shared/action_panel",
            locals: { current_user: current_user }),
          turbo_stream.update("user_data",
            partial: "user_data",
            locals: {
              games: helpers.extract_game_names(current_user.events.includes(:tournament)),
              selected_game: helpers.extract_game_names(current_user.events.includes(:tournament)).first
            })
        ]
      }
      format.html { redirect_to root_path }
    end
  end

  def sync_all
    # Check if a sync is already in progress
    if current_user.sync_in_progress?
      flash[:alert] = "A sync is already in progress. Please wait until it completes."
    else
      # Set sync_in_progress flag immediately for UI feedback
      current_user.update(sync_in_progress: true)

      # Enqueue the background job to sync all tournaments and events
      SyncAllJob.perform_later(current_user.id)
      flash[:notice] = "Sync has been scheduled and will run in the background."
    end

    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: [
          turbo_stream.update("action_panel",
            partial: "shared/action_panel",
            locals: { current_user: current_user }),
          turbo_stream.update("user_data",
            partial: "user_data",
            locals: {
              games: helpers.extract_game_names(current_user.events.includes(:tournament)),
              selected_game: helpers.extract_game_names(current_user.events.includes(:tournament)).first
            })
        ]
      }
      format.html { redirect_to root_path }
    end
  end

  private

  def check_stuck_sync
    current_user.check_sync_status if user_signed_in?
  end

  def expire_fragment_caches
    # Expire caches for current user's games
    current_user.events.pluck(:name).map do |event_name|
      game_name = helpers.normalize_game_name(event_name)
      expire_fragment("game_results_#{current_user.id}_#{game_name}")
    end
  end
end
