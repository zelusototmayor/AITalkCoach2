class ToursController < ApplicationController
  before_action :require_login

  # POST /tours/:tour_name/complete
  def complete
    tour_name = params[:tour_name]

    if current_user.complete_tour!(tour_name)
      head :ok
    else
      head :unprocessable_entity
    end
  end

  # POST /tours/reset
  def reset
    tour_name = params[:tour_name]

    if tour_name.present?
      current_user.reset_tour!(tour_name)
    else
      current_user.reset_tours!
    end

    redirect_to settings_path, notice: "App tours have been reset. You'll see them again on your next visit."
  end
end
