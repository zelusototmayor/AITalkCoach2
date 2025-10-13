class TrialSessionsController < ApplicationController
  before_action :set_trial_session
  before_action :check_not_expired

  def show
    # For trial users, we show a restricted analysis page
    @restricted_mode = true
    @is_trial = true

    # Set appropriate flash message based on session state
    if @trial_session.processing_state == 'pending'
      flash.now[:info] = 'Your recording is being analyzed. Results will appear automatically when ready.'
    elsif @trial_session.processing_state == 'failed'
      flash.now[:alert] = @trial_session.analysis_data&.dig('error') || 'Analysis failed. This was just a demo - sign up for reliable processing!'
    elsif @trial_session.processing_state == 'completed' && @trial_session.analysis_data.present?
      flash.now[:success] = 'Trial analysis complete! Sign up for detailed feedback and progress tracking.' if params[:notice].blank?
    end
  end

  private

  def set_trial_session
    @trial_session = TrialSession.find_by!(token: params[:token])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: 'Trial session not found or expired. Please try again.'
  end

  def check_not_expired
    if @trial_session.expired?
      redirect_to root_path, alert: 'This trial session has expired. Please start a new trial.'
    end
  end
end