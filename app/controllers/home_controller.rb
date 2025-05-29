class HomeController < ApplicationController
  before_action :authenticate_user!, only: [:sync_tournaments]

  def index
  end

  def sync_tournaments
    service = FetchUserTournamentsService.new(current_user)
    if service.call
      flash[:notice] = "Tournaments synced successfully!"
    else
      flash[:alert] = "Failed to sync tournaments: #{service.error_messages.join(', ')}"
    end
    redirect_to root_path
  end
end
