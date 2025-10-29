class Api::TrialSessionsController < ApplicationController
  before_action :set_trial_session
  skip_before_action :require_onboarding, only: [ :status ]

  def status
    # Get processing stage from analysis_data if available
    processing_stage = @trial_session.analysis_data&.dig("processing_stage")
    incomplete_reason = @trial_session.incomplete_reason

    render json: {
      token: @trial_session.token,
      processing_state: @trial_session.processing_state,
      processing_stage: processing_stage,
      completed: @trial_session.completed,
      incomplete_reason: incomplete_reason,
      expired: @trial_session.expired?,
      updated_at: @trial_session.updated_at,
      progress_info: get_trial_progress_info(@trial_session)
    }
  end

  private

  def set_trial_session
    # Support both token and ID lookup
    if params[:token].present?
      @trial_session = TrialSession.find_by!(token: params[:token])
    elsif params[:id].present?
      @trial_session = TrialSession.find(params[:id])
    else
      raise ActiveRecord::RecordNotFound
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Trial session not found or expired" }, status: :not_found
  end

  def get_trial_progress_info(trial_session)
    case trial_session.processing_state
    when "pending"
      {
        step: "Analysis Queued",
        progress: 5,
        estimated_time: trial_session.estimated_completion_time
      }
    when "processing"
      # Better progress indication for trial sessions
      processing_duration = Time.current - trial_session.updated_at

      if processing_duration < 5
        step_message = "Starting analysis..."
        progress = 15
      elsif processing_duration < 15
        step_message = "Transcribing speech..."
        progress = 40
      elsif processing_duration < 25
        step_message = "Analyzing patterns..."
        progress = 70
      else
        step_message = "Finalizing results..."
        progress = 90
      end

      {
        step: step_message,
        progress: progress,
        estimated_time: trial_session.estimated_completion_time
      }
    when "completed"
      {
        step: "Analysis complete",
        progress: 100,
        estimated_time: "Done"
      }
    when "failed"
      {
        step: "Analysis failed",
        progress: 0,
        estimated_time: "Please try again"
      }
    else
      {
        step: "Unknown state",
        progress: 0,
        estimated_time: "Please refresh the page"
      }
    end
  end
end
