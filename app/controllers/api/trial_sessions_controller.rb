class Api::TrialSessionsController < ApplicationController
  before_action :set_trial_session

  def status
    render json: {
      token: @trial_session.token,
      processing_state: @trial_session.processing_state,
      completed: @trial_session.completed,
      expired: @trial_session.expired?,
      updated_at: @trial_session.updated_at,
      progress_info: get_trial_progress_info(@trial_session)
    }
  end

  private

  def set_trial_session
    @trial_session = TrialSession.find_by!(token: params[:token])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Trial session not found or expired' }, status: :not_found
  end

  def get_trial_progress_info(trial_session)
    case trial_session.processing_state
    when 'pending'
      {
        step: 'Analysis Queued',
        progress: 5,
        estimated_time: trial_session.estimated_completion_time
      }
    when 'processing'
      # Better progress indication for trial sessions
      processing_duration = Time.current - trial_session.updated_at

      if processing_duration < 5
        step_message = 'Starting analysis...'
        progress = 15
      elsif processing_duration < 15
        step_message = 'Transcribing speech...'
        progress = 40
      elsif processing_duration < 25
        step_message = 'Analyzing patterns...'
        progress = 70
      else
        step_message = 'Finalizing results...'
        progress = 90
      end

      {
        step: step_message,
        progress: progress,
        estimated_time: trial_session.estimated_completion_time
      }
    when 'completed'
      {
        step: 'Analysis complete',
        progress: 100,
        estimated_time: 'Done'
      }
    when 'failed'
      {
        step: 'Analysis failed',
        progress: 0,
        estimated_time: 'Please try again'
      }
    else
      {
        step: 'Unknown state',
        progress: 0,
        estimated_time: 'Please refresh the page'
      }
    end
  end
end