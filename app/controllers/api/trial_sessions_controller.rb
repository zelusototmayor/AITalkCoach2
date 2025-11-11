class Api::TrialSessionsController < Api::V1::BaseController
  before_action :set_trial_session, only: [ :show, :status ]
  skip_before_action :authenticate_request, only: [ :create, :show, :status ]
  before_action :optional_authenticate, only: [ :create, :show, :status ]
  before_action :normalize_language, only: [ :create ]

  # Create a new trial session (for onboarding from mobile app)
  def create
    # Handle trial recording upload from mobile app
    if params[:audio_file].present? && params[:trial_recording] == "true"
      begin
        trial_session = TrialSession.create!(
          title: "Onboarding Test",
          language: params[:language] || "en",
          media_kind: params[:media_kind] || "audio",
          target_seconds: params[:target_seconds]&.to_i || 30,
          processing_state: "pending"
        )

        # Store the audio file
        trial_session.media_files.attach(params[:audio_file])

        # Process the trial session asynchronously
        Sessions::TrialProcessJob.perform_later(trial_session.token)

        # Link to user if authenticated
        if current_user
          current_user.update(onboarding_demo_session_id: trial_session.id)
        end

        # Return trial token for mobile app
        render json: {
          success: true,
          message: "Recording uploaded successfully",
          trial_token: trial_session.token
        }
      rescue => e
        Rails.logger.error "Trial recording upload error: #{e.message}"
        render json: {
          success: false,
          error: "Failed to process recording. Please try again.",
          errors: [ e.message ]
        }, status: :unprocessable_entity
      end
    else
      render json: {
        success: false,
        error: "Missing audio file or trial_recording parameter"
      }, status: :unprocessable_entity
    end
  end

  def show
    # Return full trial session results for mobile app
    render json: {
      trial_session: {
        token: @trial_session.token,
        title: @trial_session.title,
        transcript: @trial_session.transcript,
        duration_seconds: @trial_session.duration_seconds,
        processing_state: @trial_session.processing_state,
        is_mock: @trial_session.is_mock,
        metrics: {
          clarity: @trial_session.clarity_score,
          wpm: @trial_session.wpm,
          filler_words_per_minute: @trial_session.filler_words_per_minute,
          filler_rate: @trial_session.filler_rate,
          filler_count: @trial_session.filler_count,
          overall_score: @trial_session.overall_score,
          fluency_score: @trial_session.fluency_score,
          engagement_score: @trial_session.engagement_score,
          pace_consistency: @trial_session.pace_consistency
        }
      }
    }
  end

  def status
    # Prevent caching of status responses
    response.headers['Cache-Control'] = 'no-cache, no-store, must-revalidate'
    response.headers['Pragma'] = 'no-cache'
    response.headers['Expires'] = '0'

    # Get processing stage from analysis_data if available
    processing_stage = @trial_session.analysis_data&.dig("processing_stage")
    incomplete_reason = @trial_session.incomplete_reason

    render json: {
      token: @trial_session.token,
      processing_state: @trial_session.processing_state,
      processing_stage: processing_stage,
      completed: @trial_session.ready_for_display?, # Changed: redirect to report when preview ready
      fully_completed: @trial_session.completed, # Full AI analysis complete
      incomplete_reason: incomplete_reason,
      expired: @trial_session.expired?,
      updated_at: @trial_session.updated_at,
      progress_info: get_trial_progress_info(@trial_session)
    }
  end

  private

  def normalize_language
    # Normalize and validate language parameter
    if params[:language].present?
      normalized_lang = LanguageService.normalize_language_code(params[:language])

      unless LanguageService.language_supported?(normalized_lang)
        Rails.logger.warn "Unsupported language requested for trial: #{params[:language]}, falling back to English"
        params[:language] = "en"
      else
        params[:language] = normalized_lang
      end
    else
      # Default to English if no language specified
      params[:language] = "en"
    end
  end

  def optional_authenticate
    # Try to authenticate if token is provided, but don't fail if not
    @current_user = decode_token
  rescue JWT::DecodeError, JWT::ExpiredSignature
    # Ignore auth errors for optional authentication
    @current_user = nil
  end

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
      # Check if we have stored progress first
      stored_progress = trial_session.analysis_data&.dig("processing_progress")
      stored_stage = trial_session.analysis_data&.dig("processing_stage")

      if stored_progress.present?
        # Use real progress from job
        {
          step: stored_stage || "Processing...",
          progress: stored_progress,
          estimated_time: trial_session.estimated_completion_time
        }
      else
        # Fall back to time-based estimation
        # Use processing_started_at if available, otherwise fall back to updated_at
        start_time = trial_session.processing_started_at || trial_session.updated_at
        processing_duration = Time.current - start_time

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
      end
    when "preview_ready"
      {
        step: "Quick analysis complete, refining...",
        progress: 85,
        estimated_time: "Ready to view"
      }
    when "ai_analyzing"
      {
        step: "Enhancing with AI insights...",
        progress: 95,
        estimated_time: "Almost done"
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
