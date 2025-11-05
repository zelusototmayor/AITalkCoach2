class Api::V1::SessionsController < Api::V1::BaseController
  before_action :set_default_language, only: [:create]

  # GET /api/v1/sessions
  def index
    sessions = current_user.sessions
                          .where(completed: true)
                          .order(created_at: :desc)
                          .limit(params[:limit] || 50)
                          .includes(:issues)

    render json: {
      success: true,
      sessions: sessions.map { |s| session_json(s) }
    }
  end

  # GET /api/v1/sessions/:id
  def show
    session = current_user.sessions.find(params[:id])
    issues = session.issues.order(:start_ms)

    # Get previous session for comparison
    previous_session = current_user.sessions
      .where(completed: true)
      .where("id < ?", session.id)
      .order(created_at: :desc)
      .first

    # Generate recommendations if completed
    recommendations = nil
    weekly_focus = nil

    if session.completed? && session.analysis_data.present?
      begin
        recent_sessions = current_user.sessions
          .where(completed: true)
          .where("id <= ?", session.id)
          .order(created_at: :desc)
          .limit(5)
          .includes(:issues)

        total_sessions_count = current_user.sessions
          .where(completed: true)
          .where("id <= ?", session.id)
          .count

        user_context = {
          speech_context: session.speech_context || "general",
          historical_sessions: recent_sessions.to_a,
          total_sessions_count: total_sessions_count
        }

        recommender = Analysis::PriorityRecommender.new(session, user_context)
        recommendations = recommender.generate_priority_recommendations

        weekly_focus = WeeklyFocus.current_for_user(current_user)
      rescue => e
        Rails.logger.error "Priority recommendations error: #{e.message}"
      end
    end

    render json: {
      success: true,
      session: session_json(session, include_details: true),
      issues: issues.map { |i| issue_json(i) },
      previous_session: previous_session ? session_json(previous_session, include_details: true) : nil,
      priority_recommendations: recommendations,
      weekly_focus: weekly_focus
    }
  end

  # POST /api/v1/sessions
  def create
    @session = current_user.sessions.build(session_params)
    @session.processing_state = "pending"
    @session.completed = false

    # Set enforcement flag
    @session.minimum_duration_enforced = true if @session.minimum_duration_enforced.nil?

    # Set planned date if needed
    @session.planned_for_date = Date.current if @session.is_planned_session && @session.planned_for_date.nil?

    if @session.save
      # Clear cache
      Rails.cache.delete("user_#{current_user.id}_sessions_count")
      Rails.cache.delete("user_#{current_user.id}_recent_sessions")

      # Enqueue background job
      Sessions::ProcessJob.perform_later(@session.id)

      render json: {
        success: true,
        session_id: @session.id,
        message: "Recording session created successfully. Analysis will be available shortly."
      }, status: :created
    else
      render json: {
        success: false,
        errors: @session.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/sessions/:id/status
  def status
    session = current_user.sessions.find(params[:id])

    render json: {
      success: true,
      id: session.id,
      processing_state: session.processing_state,
      completed: session.completed,
      incomplete_reason: session.incomplete_reason,
      updated_at: session.updated_at,
      progress_percent: session.analysis_data&.dig("processing_progress") || calculate_progress_percent(session),
      processing_stage: session.analysis_data&.dig("processing_stage") || infer_processing_stage(session)
    }
  end

  # DELETE /api/v1/sessions/:id
  def destroy
    session = current_user.sessions.find(params[:id])
    session.destroy

    render json: {
      success: true,
      message: "Session deleted successfully"
    }
  end

  private

  def set_default_language
    # ALWAYS use the user's current preferred language from database
    # This ensures consistency even if client cache is stale
    if params[:session]
      user_language = current_user.language_for_sessions
      params[:session][:language] = user_language

      Rails.logger.info "Set session language to user's database preference: #{user_language}"

      # Validate and normalize language code
      normalized_lang = LanguageService.normalize_language_code(user_language)

      unless LanguageService.language_supported?(normalized_lang)
        Rails.logger.warn "User's preferred language '#{user_language}' not supported, falling back to English"
        params[:session][:language] = "en"
      else
        params[:session][:language] = normalized_lang
      end
    end
  end

  def session_params
    params.require(:session).permit(
      :title, :language, :media_kind, :target_seconds,
      :minimum_duration_enforced, :speech_context,
      :weekly_focus_id, :is_planned_session, :planned_for_date,
      :media_file, media_files: []
    )
  end

  def session_json(session, include_details: false)
    json = {
      id: session.id,
      title: session.title,
      created_at: session.created_at,
      completed: session.completed,
      processing_state: session.processing_state,
      duration_seconds: session.analysis_data&.dig("duration_seconds"),
      overall_score: session.analysis_data&.dig("overall_score"),
      clarity_score: session.analysis_data&.dig("clarity_score"),
      wpm: session.analysis_data&.dig("wpm"),
      filler_rate: session.analysis_data&.dig("filler_rate")
    }

    if include_details
      json.merge!({
        analysis_data: session.analysis_data,
        speech_context: session.speech_context,
        target_seconds: session.target_seconds,
        pace_consistency: session.analysis_data&.dig("pace_consistency"),
        fluency_score: session.analysis_data&.dig("fluency_score"),
        engagement_score: session.analysis_data&.dig("engagement_score"),
        micro_tips: session.micro_tips
      })
    end

    json
  end

  def issue_json(issue)
    {
      id: issue.id,
      kind: issue.kind,
      category: issue.category,
      start_ms: issue.start_ms,
      end_ms: issue.end_ms,
      severity: issue.severity,
      text: issue.text,
      tip: issue.tip,
      rationale: issue.rationale
    }
  end

  def calculate_progress_percent(session)
    case session.processing_state
    when "pending" then 5
    when "processing"
      # Use processing_started_at if available, otherwise fall back to updated_at
      start_time = session.processing_started_at || session.updated_at
      processing_duration = Time.current - start_time

      if processing_duration < 10
        15
      elsif processing_duration < 30
        35
      elsif processing_duration < 60
        60
      elsif processing_duration < 90
        80
      else
        90
      end
    when "completed" then 100
    when "failed" then 0
    else 0
    end
  end

  def infer_processing_stage(session)
    case session.processing_state
    when "pending" then "pending"
    when "processing"
      # Use processing_started_at if available, otherwise fall back to updated_at
      start_time = session.processing_started_at || session.updated_at
      processing_duration = Time.current - start_time

      if processing_duration < 10
        "extraction"
      elsif processing_duration < 30
        "transcription"
      elsif processing_duration < 60
        "analysis"
      elsif processing_duration < 90
        "refinement"
      else
        "refinement"
      end
    when "completed" then "completed"
    when "failed" then "failed"
    else "unknown"
    end
  end
end