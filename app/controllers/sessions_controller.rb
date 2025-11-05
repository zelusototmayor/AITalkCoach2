class SessionsController < ApplicationController
  # Skip CSRF verification for JSON API requests (mobile app)
  skip_before_action :verify_authenticity_token, if: -> { request.format.json? }

  before_action :activate_trial_if_requested
  before_action :require_login, except: [ :index, :create ], unless: -> { request.format.json? && Rails.env.development? }
  # Skip authentication for mobile API requests in development
  # TODO: Implement proper mobile authentication (JWT/API keys) before production
  before_action :require_login_or_trial, only: [ :index, :create ], unless: -> { request.format.json? && Rails.env.development? }
  before_action :require_subscription, except: [ :index, :create ], unless: -> { request.format.json? && Rails.env.development? }
  before_action :set_session, only: [ :show, :destroy ]

  def index
    # Safeguard: Redirect to onboarding if user is logged in but hasn't completed onboarding
    if logged_in? && current_user.needs_onboarding?
      redirect_to onboarding_splash_path, alert: "Please complete your profile setup first"
      return
    end

    # Trial mode is only available on marketing site (not app subdomain)
    # On app subdomain, users must be logged in with paid subscription
    if on_app_subdomain?
      # App subdomain: require paid subscription
      unless logged_in?
        redirect_to app_subdomain_url(login_path), allow_other_host: true, alert: "Please login to continue"
        return
      end

      unless current_user.can_access_app?
        redirect_to pricing_url, alert: "Please subscribe to access the app.", allow_other_host: true
        return
      end
    end

    if trial_mode? && !on_app_subdomain?
      # Trial mode: simplified interface (marketing site only)
      @trial_prompt = "What was something you enjoyed about last week and why?"
      @default_prompt = @trial_prompt
      @default_prompt_data = { prompt: @trial_prompt, target_seconds: 30 }

      # Check for trial results to display
      if params[:trial_results] == "true" && session[:trial_results]
        @trial_results = session[:trial_results]
        session.delete(:trial_results) # Clear after showing
      end

      # No metrics for trial users - they'll see trial results after recording
      @recent_sessions = []
      @quick_metrics = {}
      @focus_areas = []
      @current_streak = 0
      @enforcement_analytics = {}

      # Simplified prompts for trial
      @prompts = {}
      @adaptive_prompts = {}
      @categories = []
      @user_weaknesses = []
    elsif logged_in? && current_user.can_access_app?
      # Regular authenticated flow
      # Note: Analytics tracking for real_session_started happens on the frontend
      @prompts = load_prompts_from_config
      @adaptive_prompts = get_adaptive_prompts
      @categories = (@prompts.keys + [ "recommended" ]).uniq.sort
      @user_weaknesses = analyze_user_weaknesses

      # Quick metrics for insights panel (30-day averages)
      @recent_sessions = current_user.sessions
                                     .where(completed: true)
                                     .where("sessions.created_at > ?", 30.days.ago)
                                     .order("sessions.created_at DESC")
                                     .limit(10)
                                     .includes(:issues)

      # Lifetime metrics for Performance Metrics section
      @lifetime_session_count = current_user.sessions.where(completed: true).count
      # Calculate in Ruby because duration is stored in JSON, not a DB column
      @lifetime_total_minutes = (
        current_user.sessions
                    .where(completed: true)
                    .to_a
                    .sum { |s| s.duration_seconds.to_f } / 60.0
      ).round

      @quick_metrics = calculate_quick_metrics(@recent_sessions)
      @focus_areas = generate_focus_areas
      @current_streak = calculate_current_streak
      @enforcement_analytics = calculate_enforcement_analytics

      # Check if user has any sessions at all (for empty state)
      @has_any_sessions = current_user.sessions.exists?

      # Generate weekly goal data for practice dashboard
      @latest_session = @recent_sessions.first
      if @latest_session
        begin
          total_sessions_count = current_user.sessions.where(completed: true).count
          user_context = {
            speech_context: @latest_session.speech_context || "general",
            historical_sessions: @recent_sessions.to_a,
            total_sessions_count: total_sessions_count
          }
          recommender = Analysis::PriorityRecommender.new(@latest_session, user_context)
          @priority_recommendations = recommender.generate_priority_recommendations
          @weekly_focus = recommender.create_or_update_weekly_focus(current_user)

          # Calculate weekly focus tracking metrics
          if @weekly_focus
            @weekly_focus_tracking = calculate_weekly_focus_tracking(@weekly_focus)
          end
        rescue => e
          Rails.logger.error "Weekly goal error: #{e.message}"
          @priority_recommendations = nil
          @weekly_focus = nil
          @weekly_focus_tracking = nil
        end
      end

      # Handle prompt parameters from recommended/selected prompts
      if params[:adaptive_prompt] && params[:category] && params[:index]
        # User clicked on an adaptive/recommended prompt
        @default_prompt_data = get_adaptive_prompt_data(params[:category], params[:index].to_i)
        @default_prompt = @default_prompt_data[:prompt]
      elsif params[:prompt_id]
        # User clicked on a regular prompt
        @default_prompt_data = get_prompt_by_id(params[:prompt_id])
        @default_prompt = @default_prompt_data[:prompt]
      else
        # Set a default prompt if none available
        @default_prompt = get_default_prompt
        @default_prompt_data = get_default_prompt_data
      end
    else
      # Not logged in or no subscription - redirect to pricing
      redirect_to pricing_url, alert: "Please subscribe to access the app.", allow_other_host: true
    end
  end

  def history
    # Force fresh data by disabling query cache and ensuring latest data
    ActiveRecord::Base.uncached do
      @sessions = current_user.sessions
                              .order(created_at: :desc)
                              .includes(:issues)
                              .limit(50) # Reasonable limit for performance
    end

    # Clear any relevant cache keys for this user
    Rails.cache.delete("user_#{current_user.id}_sessions_count")
    Rails.cache.delete("user_#{current_user.id}_recent_sessions")
  end

  def coach
    # For mobile API in development, get user from params
    if request.format.json? && Rails.env.development?
      # Handle both numeric IDs and string identifiers
      if params[:user_id].to_i > 0
        user = User.find(params[:user_id])
      else
        # For string identifiers like "test-user", look up by email pattern
        user = User.find_by!(email: "mobile_#{params[:user_id]}@dev.local")
      end
    else
      user = current_user
    end

    # Get all completed sessions for context
    @recent_sessions = user.sessions
                                   .where(completed: true)
                                   .order("sessions.created_at ASC")
                                   .includes(:issues)

    # Get the most recent completed session for last session insight
    @latest_session = @recent_sessions.last

    # Generate priority recommendations if we have a recent session
    if @latest_session
      begin
        # Get total session count for accurate first-session detection
        total_sessions_count = user.sessions.where(completed: true).count

        user_context = {
          speech_context: @latest_session.speech_context || "general",
          historical_sessions: @recent_sessions.to_a,
          total_sessions_count: total_sessions_count
        }
        recommender = Analysis::PriorityRecommender.new(@latest_session, user_context)
        @priority_recommendations = recommender.generate_priority_recommendations

        # Get or create weekly focus
        @weekly_focus = recommender.create_or_update_weekly_focus(user)
      rescue => e
        Rails.logger.error "Priority recommendations error: #{e.message}"
        @priority_recommendations = nil
        @weekly_focus = nil
      end
    else
      @weekly_focus = nil
    end

    # Generate daily plan based on weekly focus
    if @weekly_focus
      plan_generator = Planning::DailyPlanGenerator.new(@weekly_focus, user)
      @daily_plan = plan_generator.generate_plan

      # Calculate weekly focus tracking metrics
      @weekly_focus_tracking = calculate_weekly_focus_tracking(@weekly_focus)
    else
      @daily_plan = nil
      @weekly_focus_tracking = nil
    end

    # Prepare calendar data (full year for habit tracking)
    @calendar_data = prepare_calendar_data(@recent_sessions)

    # Prepare last session insight data
    @last_session_insight = prepare_last_session_insight(@latest_session, @priority_recommendations) if @latest_session

    # Return JSON for mobile API
    if request.format.json?
      render json: {
        priority_recommendations: @priority_recommendations,
        weekly_focus: @weekly_focus,
        daily_plan: @daily_plan,
        weekly_focus_tracking: @weekly_focus_tracking,
        latest_session: @latest_session ? {
          id: @latest_session.id,
          created_at: @latest_session.created_at,
          analysis_data: @latest_session.analysis_data
        } : nil,
        last_session_insight: @last_session_insight
      }
    end
  end

  def progress
    # For mobile API in development, use user_id param instead of current_user
    user = if request.format.json? && Rails.env.development? && params[:user_id]
             User.find_by(id: params[:user_id]) || User.first # Fallback to first user if not found
           else
             current_user
           end

    # Get all completed sessions for progress tracking
    # Note: We load all sessions (not just last 30 days) to ensure users with historical data
    # can see their progress dashboard and get recommendations even after practice gaps
    @recent_sessions = user.sessions
                                   .where(completed: true)
                                   .order("sessions.created_at ASC")  # ASC for chronological charts
                                   .includes(:issues)

    # Get the most recent completed session for context
    @latest_session = @recent_sessions.last

    # Get weekly focus to highlight the focused metric
    @weekly_focus = WeeklyFocus.current_for_user(user)

    # Prepare chart data for frontend with time range
    @time_range = params[:range] || params[:time_range] || "7"
    @chart_data = prepare_progress_chart_data(@recent_sessions, @time_range)

    # Prepare skill snapshot data (current vs previous session)
    @skill_snapshot = prepare_skill_snapshot_data(@recent_sessions)

    # Prepare calendar data (full year)
    @calendar_data = prepare_calendar_data(@recent_sessions)

    # Detect achievements and milestones
    begin
      achievement_detector = Analysis::AchievementDetector.new(user)
      @achievements = achievement_detector.detect_achievements
      @recent_milestones = achievement_detector.detect_recent_milestones
    rescue => e
      Rails.logger.error "Achievement detection error: #{e.message}"
      @achievements = []
      @recent_milestones = []
    end

    respond_to do |format|
      format.html # renders progress.html.erb
      format.json {
        render json: {
          chart_data: @chart_data,
          current_values: extract_current_values(@recent_sessions),
          best_values: extract_best_values(@recent_sessions),
          trends: extract_trends(@recent_sessions),
          deltas: extract_deltas(@recent_sessions),
          skill_snapshot: @skill_snapshot,
          calendar_data: @calendar_data,
          achievements: @achievements,
          recent_milestones: @recent_milestones,
          weekly_focus: @weekly_focus
        }
      }
    end
  end


  def create
    # Mobile API requests in development (temporary - implement proper auth before production)
    if request.format.json? && Rails.env.development?
      handle_mobile_session
    # Trial sessions only allowed on marketing site, not app subdomain
    elsif trial_mode? && !on_app_subdomain?
      # Handle trial session - no DB persistence
      handle_trial_session
    elsif logged_in? && current_user.can_access_app?
      # Regular authenticated session
      @session = current_user.sessions.build(session_params)
      @session.processing_state = "pending"
      @session.completed = false

      # Set enforcement flag based on whether it's coming from practice interface
      # If not explicitly set, default to true for practice interface sessions
      if @session.minimum_duration_enforced.nil?
        @session.minimum_duration_enforced = true
      end

      # Set planned_for_date to today if this is a planned session from daily plan
      if @session.is_planned_session && @session.planned_for_date.nil?
        @session.planned_for_date = Date.current
      end

      if @session.save
        # Clear cache to ensure history page shows new session
        Rails.cache.delete("user_#{current_user.id}_sessions_count")
        Rails.cache.delete("user_#{current_user.id}_recent_sessions")

        # Enqueue background job for processing
        Sessions::ProcessJob.perform_later(@session.id)

        # Handle AJAX vs traditional requests differently
        if request.xhr?
          # AJAX request - return JSON response
          render json: {
            success: true,
            session_id: @session.id,
            redirect_url: session_path(@session),
            message: "Recording session created successfully. Analysis will be available shortly."
          }, status: :created
        else
          # Traditional request - redirect as before
          redirect_to @session, notice: "Recording session created successfully. Analysis will be available shortly."
        end
      else
        # Handle validation errors
        if request.xhr?
          # AJAX request - return error response with detailed error info
          error_messages = @session.errors.full_messages
          primary_message = if error_messages.any?
            error_messages.first
          else
            "Please record audio before submitting"
          end

          Rails.logger.error "Session validation failed: #{error_messages.join(', ')}"

          render json: {
            success: false,
            errors: error_messages,
            message: primary_message
          }, status: :unprocessable_entity
        else
          # Traditional request - render form with errors
          @prompts = load_prompts_from_config
          @adaptive_prompts = get_adaptive_prompts
          @categories = (@prompts.keys + [ "recommended" ]).uniq.sort
          @user_weaknesses = analyze_user_weaknesses
          render :index, status: :unprocessable_content
        end
      end
    else
      # Not authorized - redirect to pricing
      if request.xhr?
        render json: {
          success: false,
          message: "Please subscribe to access the app.",
          redirect_url: pricing_url
        }, status: :forbidden
      else
        redirect_to pricing_url, alert: "Please subscribe to access the app."
      end
    end
  end

  def show
    # For mobile API in development, find session without user authentication
    if request.format.json? && Rails.env.development?
      @session = Session.find(params[:id])
      user = @session.user
    else
      user = current_user
    end

    @issues = @session.issues.order(:start_ms)

    # Generate priority-based recommendations for completed sessions
    if @session.completed? && @session.analysis_data.present?
      begin
        # Get last 5 sessions for historical context
        recent_sessions = user.sessions
          .where(completed: true)
          .where("id <= ?", @session.id) # Include current + previous
          .order(created_at: :desc)
          .limit(5)
          .includes(:issues)

        # Get total session count for accurate first-session detection
        total_sessions_count = user.sessions
          .where(completed: true)
          .where("id <= ?", @session.id)
          .count

        user_context = {
          speech_context: @session.speech_context || params[:context] || "general",
          historical_sessions: recent_sessions.to_a,
          total_sessions_count: total_sessions_count
        }
        recommender = Analysis::PriorityRecommender.new(@session, user_context)
        @priority_recommendations = recommender.generate_priority_recommendations
      rescue => e
        Rails.logger.error "Priority recommendations error: #{e.message}"
        @priority_recommendations = nil
      end

      # Check if user has active weekly focus and match with recommendations
      @weekly_focus = WeeklyFocus.current_for_user(user)

      if @weekly_focus && @priority_recommendations&.dig(:focus_this_week)&.any?
        top_rec = @priority_recommendations[:focus_this_week].first
        @recommendation_matches_focus = Analysis::PriorityRecommender.matches_focus_type?(
          top_rec[:type],
          @weekly_focus.focus_type
        )

        # Calculate weekly progress
        @weekly_progress = {
          completed: @weekly_focus.completed_sessions_count,
          target: @weekly_focus.target_sessions_per_week,
          percentage: @weekly_focus.completion_percentage
        }
      else
        @recommendation_matches_focus = false
        @weekly_progress = nil
      end

      # Load micro-tips for Quick Wins section (Phase 2)
      # Filter out tips that duplicate focus areas AND primary recommendation
      begin
        @micro_tips = @session.micro_tips || []

        # Convert to OpenStruct for easier view access
        @micro_tips = @micro_tips.map { |tip| OpenStruct.new(tip.symbolize_keys) }

        # Get primary recommendation type for filtering
        primary_rec_type = @priority_recommendations&.dig(:focus_this_week, 0, :type)

        # Extract focus area types from recommendations for deduplication
        if @priority_recommendations&.dig(:focus_this_week)&.any?
          focus_types = @priority_recommendations[:focus_this_week].map { |rec| rec[:type] }

          # Map recommendation types to tip categories for filtering
          focus_categories = focus_types.map do |type|
            case type
            when "reduce_fillers" then "filler_words"
            when "improve_pace" then "pace_consistency"
            when "fix_long_pauses" then "pause_consistency"
            when "boost_engagement" then "energy"
            when "increase_fluency" then "fluency"
            else type
            end
          end

          # Filter out tips that match focus areas or primary recommendation
          @micro_tips = @micro_tips.reject { |tip| focus_categories.include?(tip.category) }
        end

        # Limit to top 2 tips for UI
        @micro_tips = @micro_tips.first(2)

        Rails.logger.info "Loaded #{@micro_tips.length} micro-tips for session #{@session.id}"
      rescue => e
        Rails.logger.error "Error loading micro-tips: #{e.message}"
        @micro_tips = []
      end
    end

    # Set appropriate flash message based on session state
    if @session.processing_state == "pending"
      flash.now[:info] = "Your session is being processed. Analysis results will appear automatically when ready."
    elsif @session.processing_state == "failed"
      flash.now[:alert] = "Session analysis failed. Please try re-processing or contact support."
    elsif @session.processing_state == "completed" && @session.analysis_data.present?
      flash.now[:success] = "Analysis complete! Review your detailed feedback below." if params[:notice].blank?
    end

    # Prepare sessions data for insights controller
    begin
      @user_sessions = user.sessions
                                    .where(completed: true)
                                    .where("sessions.created_at > ?", 90.days.ago)
                                    .order("sessions.created_at DESC")
                                    .limit(50)
                                    .includes(:issues)
                                    .map do |session|
        {
          id: session.id,
          created_at: session.created_at&.iso8601,
          analysis_data: session.analysis_data || {},
          duration: (session.analysis_data&.dig("duration_seconds")&.to_f rescue 0),
          metrics: {
            clarity_score: (session.analysis_data&.dig("clarity_score")&.to_f rescue nil),
            wpm: (session.analysis_data&.dig("wpm")&.to_f rescue nil),
            filler_rate: (session.analysis_data&.dig("filler_rate")&.to_f rescue nil),
            pace_consistency: (session.analysis_data&.dig("pace_consistency")&.to_f rescue nil),
            volume_consistency: (session.analysis_data&.dig("speech_to_silence_ratio")&.to_f rescue nil),
            engagement_score: (session.analysis_data&.dig("engagement_score")&.to_f rescue nil),
            fluency_score: (session.analysis_data&.dig("fluency_score")&.to_f rescue nil),
            overall_score: (session.analysis_data&.dig("overall_score")&.to_f rescue nil)
          }
        }
      end
    rescue => e
      Rails.logger.error "Error preparing sessions data for insights: #{e.message}"
      @user_sessions = []
    end

    # Return JSON for mobile API
    if request.format.json?
      render json: {
        id: @session.id,
        user_id: @session.user_id,
        title: @session.title,
        created_at: @session.created_at,
        completed: @session.completed,
        processing_state: @session.processing_state,
        analysis_data: @session.analysis_data,
        analysis_json: @session.analysis_data,  # Alias for mobile app compatibility
        issues: @issues.map { |issue|
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
        },
        priority_recommendations: @priority_recommendations,
        weekly_focus: @weekly_focus,
        weekly_progress: @weekly_progress,
        micro_tips: @micro_tips
      }
    end
  end

  def destroy
    @session.destroy
    redirect_to practice_path, notice: "Session deleted successfully."
  end

  def status
    # For mobile API in development, find session without user authentication
    if request.format.json? && Rails.env.development?
      @session = Session.find(params[:id])
    else
      @session = current_user.sessions.find(params[:id])
    end

    render json: {
      id: @session.id,
      processing_state: @session.processing_state,
      completed: @session.completed,
      incomplete_reason: @session.incomplete_reason,
      updated_at: @session.updated_at,
      progress_percent: @session.analysis_data&.dig("processing_progress") || calculate_progress_percent(@session),
      processing_stage: @session.analysis_data&.dig("processing_stage") || infer_processing_stage(@session)
    }
  end

  # Make the helper methods available to views
  helper_method :normalize_metric_for_display, :humanize_improvement_type, :format_metric_value, :format_effort_level

  private

  def set_session
    # For mobile API in development, find session without user authentication
    if request.format.json? && Rails.env.development?
      @session = Session.find(params[:id])
    else
      @session = current_user.sessions.find(params[:id])
    end
  end

  # Helper method to convert decimal metrics to percentage for display
  def normalize_metric_for_display(session, metric_key)
    value = session.analysis_data[metric_key]
    return nil unless value.present?

    # All metrics are now consistently stored as decimals (0.85 = 85%)
    case metric_key
    when "filler_rate", "clarity_score", "fluency_score", "engagement_score", "pace_consistency", "overall_score"
      (value * 100).round(1)
    else
      value
    end
  end

  def humanize_improvement_type(type)
    case type
    when "reduce_fillers" then "Reduce Filler Words"
    when "improve_pace" then "Improve Speaking Pace"
    when "enhance_clarity" then "Enhance Speech Clarity"
    when "boost_engagement" then "Boost Engagement"
    when "increase_fluency" then "Increase Fluency"
    when "fix_long_pauses" then "Fix Long Pauses"
    when "professional_language" then "Use Professional Language"
    else type.humanize
    end
  end

  def format_metric_value(value, type)
    case type
    when "reduce_fillers"
      "#{(value * 100).round(1)}%"
    when "improve_pace"
      "#{value.round} WPM"
    when "enhance_clarity", "boost_engagement", "increase_fluency"
      "#{(value * 100).round}%"
    when "fix_long_pauses"
      "#{value} pauses"
    when "professional_language"
      "#{value} issues"
    else
      value.to_s
    end
  end

  def format_effort_level(level)
    case level
    when 1 then "Easy"
    when 2 then "Moderate"
    when 3 then "Hard"
    when 4 then "Very Hard"
    else "Unknown"
    end
  end


  def session_params
    params.require(:session).permit(:title, :language, :media_kind, :target_seconds, :minimum_duration_enforced, :speech_context, :weekly_focus_id, :is_planned_session, :planned_for_date, :media_file, media_files: [])
  end

  def extract_session_metrics(session)
    return {} unless session.analysis_data.present?

    analysis = session.analysis_data
    issues_count = session.issues.count

    {
      clarity_score: analysis["clarity_score"] || calculate_clarity_from_issues(session),
      words_per_minute: analysis["wpm"],
      filler_rate: analysis["filler_rate"],
      pace_consistency: calculate_pace_consistency(session),
      volume_consistency: calculate_volume_consistency(session),
      engagement_score: calculate_engagement_score(session)
    }.compact
  end

  def calculate_clarity_from_issues(session)
    return nil unless session.duration_ms && session.duration_ms > 0

    total_issue_duration = session.issues.sum(&:duration_ms) || 0
    clarity_score = 1.0 - (total_issue_duration.to_f / session.duration_ms)
    [ clarity_score, 0.0 ].max
  end

  def calculate_pace_consistency(session)
    return nil unless session.analysis_data["wpm"]

    # Simple consistency measure - would be enhanced with actual variance calculation
    wpm = session.analysis_data["wpm"].to_f
    ideal_wpm = 150.0
    deviation = (wpm - ideal_wpm).abs / ideal_wpm
    consistency = 1.0 - [ deviation, 1.0 ].min
    [ consistency, 0.0 ].max
  end

  def calculate_volume_consistency(session)
    # Placeholder for volume analysis - would analyze audio amplitude variance
    0.8
  end

  def calculate_engagement_score(session)
    return nil unless session.analysis_data["clarity_score"] && session.analysis_data["wpm"]

    clarity = session.analysis_data["clarity_score"].to_f
    wpm_score = [ session.analysis_data["wpm"].to_f / 150.0, 1.0 ].min
    filler_penalty = (session.analysis_data["filler_rate"] || 0) * 2

    engagement = (clarity + wpm_score - filler_penalty) / 2.0
    [ [ engagement, 0.0 ].max, 1.0 ].min
  end

  def load_prompts_from_config
    begin
      config = YAML.load_file(Rails.root.join("config", "prompts.yml"))
      base_prompts = config["base_prompts"] || {}
      Rails.logger.debug "Loaded YAML prompts: #{base_prompts.keys}"
      # Ensure we return a valid hash, never nil
      base_prompts.is_a?(Hash) ? base_prompts : {}
    rescue StandardError => e
      Rails.logger.error "Failed to load prompts from config: #{e.message}"
      {}
    end
  end

  def get_adaptive_prompts
    return {} unless current_user

    config = YAML.load_file(Rails.root.join("config", "prompts.yml"))
    weaknesses = analyze_user_weaknesses

    return {} if weaknesses.empty?

    adaptive_prompts = {}

    weaknesses.each do |weakness|
      if config["adaptive_prompts"][weakness]
        adaptive_prompts[weakness] = config["adaptive_prompts"][weakness]
      end
    end

    adaptive_prompts
  end

  def analyze_user_weaknesses
    return [] unless current_user

    # Get recent sessions for analysis
    recent_sessions = current_user.sessions
      .where(completed: true)
      .where("sessions.created_at >= ?", 30.days.ago)
      .includes(:issues)

    return [] if recent_sessions.count < 3

    config = YAML.load_file(Rails.root.join("config", "prompts.yml"))
    thresholds = config["recommendation_settings"]["issue_thresholds"]

    weaknesses = []
    session_count = recent_sessions.count.to_f

    # Analyze filler words
    filler_sessions = recent_sessions.select do |session|
      session.issues.any? { |issue| issue.category == "filler_words" }
    end
    if (filler_sessions.count / session_count) >= thresholds["filler_words"]
      weaknesses << "filler_words"
    end

    # Analyze pace issues
    pace_sessions = recent_sessions.select do |session|
      wpm = session.analysis_data["wpm"]
      wpm && (wpm < 110 || wpm > 190)
    end
    if (pace_sessions.count / session_count) >= thresholds["pace_issues"]
      weaknesses << "pace_issues"
    end

    # Analyze clarity issues
    clarity_sessions = recent_sessions.select do |session|
      clarity = session.analysis_data["clarity_score"]
      clarity && clarity < 0.7
    end
    if (clarity_sessions.count / session_count) >= thresholds["clarity_issues"]
      weaknesses << "clarity_issues"
    end

    # Analyze confidence issues (based on volume and filler frequency)
    confidence_sessions = recent_sessions.select do |session|
      filler_rate = session.analysis_data["filler_rate"]
      issue_count = session.issues.count
      duration_seconds = (session.duration_ms || 0) / 1000.0

      (filler_rate && filler_rate > 0.05) || (duration_seconds > 0 && issue_count / duration_seconds > 0.1)
    end
    if (confidence_sessions.count / session_count) >= thresholds["confidence_issues"]
      weaknesses << "confidence_issues"
    end

    # Analyze engagement issues (based on monotone speech patterns)
    engagement_sessions = recent_sessions.select do |session|
      clarity = session.analysis_data["clarity_score"]
      wpm = session.analysis_data["wpm"]
      # Simple heuristic: low variation in metrics suggests low engagement
      clarity && wpm && clarity < 0.8 && (wpm < 130 || wpm > 170)
    end
    if (engagement_sessions.count / session_count) >= thresholds["engagement_issues"]
      weaknesses << "engagement_issues"
    end

    weaknesses.uniq
  end

  def calculate_quick_metrics(sessions)
    return {} if sessions.empty?

    # Calculate 30-day average metrics for the Practice Insights panel
    # These are rolling averages used to show user's recent performance trends
    # Use caching for expensive calculations
    # Get the latest updated_at from sessions without the join to avoid ambiguity
    latest_update = current_user.sessions
                                 .where(id: sessions.map(&:id))
                                 .maximum("sessions.updated_at")
    cache_key = "user_#{current_user.id}_quick_metrics_#{latest_update&.to_i}"

    Rails.cache.fetch(cache_key, expires_in: 15.minutes) do
      # Get lifetime total count from database, not from the limited sessions array
      total_sessions = current_user.sessions
                                   .where(completed: true)
                                   .count

      wpm_values = sessions.filter_map { |s| s.analysis_data["wpm"] }
      filler_values = sessions.filter_map { |s| s.analysis_data["filler_rate"] }
      clarity_values = sessions.filter_map { |s| s.analysis_data["clarity_score"] }

      avg_wpm = wpm_values.any? ? wpm_values.sum / wpm_values.count.to_f : 0
      avg_filler_rate = filler_values.any? ? filler_values.sum / filler_values.count.to_f : 0
      avg_clarity = clarity_values.any? ? clarity_values.sum / clarity_values.count.to_f : 0

      {
        avg_wpm: avg_wpm.round,
        filler_rate: (avg_filler_rate * 100).round(1),
        clarity_score: (avg_clarity * 100).round,
        total_sessions: total_sessions
      }
    end
  end

  def generate_focus_areas
    return [] unless @user_weaknesses.any?

    focus_recommendations = {
      "filler_words" => "Reduce filler words below 3% using pause drills",
      "pace_issues" => "Target 140-170 WPM in 60s sessions",
      "clarity_issues" => "Practice concise answers (30s prompts)",
      "confidence_issues" => "Build confidence with storytelling prompts",
      "engagement_issues" => "Add energy and vary vocal tone"
    }

    @user_weaknesses.map { |weakness| focus_recommendations[weakness] }.compact
  end

  def calculate_current_streak
    # Cache streak calculation since it's expensive and doesn't change often
    cache_key = "user_#{current_user.id}_current_streak_#{Date.current}"

    Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      sessions = current_user.sessions
                              .where(completed: true)
                              .order(created_at: :desc)
                              .limit(30)

      return 0 if sessions.empty?

      streak = 0
      current_date = Date.current
      session_dates = sessions.map { |s| s.created_at.to_date }.uniq

      session_dates.each do |session_date|
        if session_date == current_date
          streak += 1
          current_date -= 1.day
        else
          break
        end
      end

      streak
    end
  end

  def calculate_enforcement_analytics
    return {} unless current_user

    # Get recent enforced sessions for analytics
    enforced_sessions = current_user.sessions
                                    .where(minimum_duration_enforced: true)
                                    .where("sessions.created_at > ?", 30.days.ago)

    return {} if enforced_sessions.empty?

    total_enforced = enforced_sessions.count
    completed_enforced = enforced_sessions.where(completed: true).count
    incomplete_enforced = total_enforced - completed_enforced

    completion_rate = (completed_enforced.to_f / total_enforced * 100).round(1)

    {
      total_enforced_sessions: total_enforced,
      completed_sessions: completed_enforced,
      incomplete_sessions: incomplete_enforced,
      completion_rate: completion_rate,
      improvement_trend: calculate_completion_trend(enforced_sessions)
    }
  end

  def calculate_completion_trend(sessions)
    return "stable" if sessions.count < 6

    # Compare recent vs earlier completion rates
    half_point = sessions.count / 2
    recent_sessions = sessions.limit(half_point)
    earlier_sessions = sessions.offset(half_point)

    recent_rate = recent_sessions.where(completed: true).count.to_f / recent_sessions.count
    earlier_rate = earlier_sessions.where(completed: true).count.to_f / earlier_sessions.count

    if recent_rate > earlier_rate + 0.1
      "improving"
    elsif recent_rate < earlier_rate - 0.1
      "declining"
    else
      "stable"
    end
  end

  def get_default_prompt
    data = get_default_prompt_data
    data[:prompt]
  end

  def get_default_prompt_data
    # Try to get from adaptive prompts first
    if @adaptive_prompts.any?
      category, prompts = @adaptive_prompts.first
      if prompts.is_a?(Array) && prompts.any?
        first_prompt = prompts.first
        if first_prompt.is_a?(Hash)
          return {
            prompt: first_prompt["prompt"],
            target_seconds: first_prompt["target_seconds"] || 60,
            title: first_prompt["title"],
            description: first_prompt["description"]
          }
        else
          return { prompt: first_prompt, target_seconds: 60 }
        end
      end
    end

    # Try to get from regular prompts
    if @prompts.any?
      category, prompts = @prompts.first
      if prompts.is_a?(Array) && prompts.any?
        first_prompt = prompts.first
        if first_prompt.is_a?(Hash)
          return {
            prompt: first_prompt["prompt"],
            target_seconds: first_prompt["target_seconds"] || 60,
            title: first_prompt["title"],
            description: first_prompt["description"]
          }
        else
          return { prompt: first_prompt, target_seconds: 60 }
        end
      end
    end

    # Fallback default
    {
      prompt: "What trade-off did you make recently and why?",
      target_seconds: 60,
      title: "Quick Question",
      description: "A simple prompt to get started"
    }
  end

  def get_adaptive_prompt_data(category, index)
    return get_default_prompt_data unless @adaptive_prompts[category]

    prompts = @adaptive_prompts[category]
    return get_default_prompt_data unless prompts.is_a?(Array) && prompts[index]

    selected_prompt = prompts[index]
    if selected_prompt.is_a?(Hash)
      {
        prompt: selected_prompt["prompt"],
        target_seconds: selected_prompt["target_seconds"] || 60,
        title: selected_prompt["title"],
        description: selected_prompt["description"]
      }
    else
      {
        prompt: selected_prompt,
        target_seconds: 60,
        title: "Recommended Prompt",
        description: "AI-recommended prompt based on your practice history"
      }
    end
  end

  def get_prompt_by_id(prompt_id)
    # Parse prompt_id like "category_index"
    parts = prompt_id.split("_")
    return get_default_prompt_data unless parts.length >= 2

    category = parts[0..-2].join("_")  # Handle category names with underscores
    index = parts[-1].to_i

    return get_default_prompt_data unless @prompts[category]

    prompts = @prompts[category]
    return get_default_prompt_data unless prompts.is_a?(Array) && prompts[index]

    selected_prompt = prompts[index]
    if selected_prompt.is_a?(Hash)
      {
        prompt: selected_prompt["prompt"],
        target_seconds: selected_prompt["target_seconds"] || 60,
        title: selected_prompt["title"],
        description: selected_prompt["description"]
      }
    else
      {
        prompt: selected_prompt,
        target_seconds: 60,
        title: "Practice Prompt",
        description: "Selected from the prompt library"
      }
    end
  end

  # Subdomain detection
  def on_app_subdomain?
    request.subdomain.present? && request.subdomain == "app"
  end

  # Trial mode helpers
  def require_login_or_trial
    # On app subdomain, require paid subscription (no trial access)
    if on_app_subdomain?
      return if logged_in? && current_user.can_access_app?

      unless logged_in?
        store_location
        redirect_to app_subdomain_url(login_path), allow_other_host: true, alert: "Please login to continue"
        return
      end

      # Logged in but no subscription
      redirect_to pricing_url, alert: "Please subscribe to access the app.", allow_other_host: true
      return
    end

    # Marketing site: allow trial access or login
    return if logged_in?

    # Allow trial access if trial parameter is present or trial is already active
    if params[:trial] == "true" || trial_mode?
      return
    end

    # Redirect to marketing site with trial option
    store_location
    redirect_to marketing_subdomain_url("/?trial=true"), allow_other_host: true, alert: "Please login or try our demo"
  end

  def handle_mobile_session
    # Mobile API session creation (development only - no authentication required)
    # TODO: Implement proper authentication (JWT/API keys) before production

    Rails.logger.info "Mobile API session params: #{params.inspect}"

    # Get or create user based on user_id from params
    user_id = params.dig(:session, :user_id)

    if user_id.blank?
      render json: {
        success: false,
        error: "user_id is required"
      }, status: :unprocessable_entity
      return
    end

    # For development, find or create a user with this ID
    # In production, this should validate a JWT token instead
    user = User.find_or_create_by!(email: "mobile_#{user_id}@dev.local") do |u|
      u.password = SecureRandom.hex(32)
      u.name = "Mobile User #{user_id}"
    end

    # Create session for this user
    @session = user.sessions.new
    @session.processing_state = "pending"
    @session.completed = false

    # Set basic attributes from params
    @session.title = params.dig(:session, :title) if params.dig(:session, :title)
    @session.language = params.dig(:session, :language) || "en"
    @session.media_kind = params.dig(:session, :media_kind) || "audio"
    @session.target_seconds = params.dig(:session, :target_seconds)&.to_i || 30
    @session.speech_context = params.dig(:session, :speech_context)
    @session.weekly_focus_id = params.dig(:session, :weekly_focus_id)

    # Attach media file (handle both singular and plural)
    if params.dig(:session, :media_file).present?
      @session.media_files.attach(params.dig(:session, :media_file))
    elsif params.dig(:session, :media_files).present?
      @session.media_files.attach(params.dig(:session, :media_files))
    end

    # Set enforcement flag
    if @session.minimum_duration_enforced.nil?
      @session.minimum_duration_enforced = true
    end

    # Set planned_for_date if needed
    if @session.is_planned_session && @session.planned_for_date.nil?
      @session.planned_for_date = Date.current
    end

    if @session.save
      # Clear cache
      Rails.cache.delete("user_#{user.id}_sessions_count")
      Rails.cache.delete("user_#{user.id}_recent_sessions")

      # Enqueue background job for processing
      Sessions::ProcessJob.perform_later(@session.id)

      # Return JSON response
      render json: {
        success: true,
        id: @session.id,
        session_id: @session.id,
        message: "Recording session created successfully. Analysis will be available shortly."
      }, status: :created
    else
      # Handle validation errors
      error_messages = @session.errors.full_messages
      primary_message = error_messages.any? ? error_messages.first : "Please record audio before submitting"

      Rails.logger.error "Mobile session validation failed: #{error_messages.join(', ')}"

      render json: {
        success: false,
        errors: error_messages,
        error: primary_message
      }, status: :unprocessable_entity
    end
  end

  def handle_trial_session
    # Mark trial as used
    mark_trial_used

    # Log incoming parameters for debugging
    Rails.logger.info "Trial session params: #{params.inspect}"
    Rails.logger.info "Session media_files param: #{params.dig(:session, :media_files)}"

    # Get the uploaded file
    uploaded_file = params.dig(:session, :media_files, 0)

    # Enhanced validation and error handling
    if uploaded_file.blank?
      Rails.logger.error "Trial session: No uploaded file found in params"
      Rails.logger.error "Full params structure: #{params.to_unsafe_h}"

      error_message = "Please record audio before submitting"
      if request.xhr?
        render json: {
          success: false,
          message: error_message
        }, status: :unprocessable_entity
        return
      else
        flash[:alert] = error_message
        redirect_to practice_path(trial: true) and return
      end
    end

    # Validate file properties
    if uploaded_file.respond_to?(:tempfile) && uploaded_file.tempfile.size == 0
      Rails.logger.error "Trial session: Uploaded file is empty (0 bytes)"

      error_message = "Recording file is empty. Please record again."
      if request.xhr?
        render json: {
          success: false,
          message: error_message
        }, status: :unprocessable_entity
        return
      else
        flash[:alert] = error_message
        redirect_to practice_path(trial: true) and return
      end
    end

    # Log file info for debugging
    Rails.logger.info "Trial session file info: #{uploaded_file.original_filename}, #{uploaded_file.size} bytes, #{uploaded_file.content_type}"

    # Create trial session with background processing
    @trial_session = TrialSession.create!(
      title: params.dig(:session, :title) || "Trial Recording",
      language: params.dig(:session, :language) || "en",
      media_kind: params.dig(:session, :media_kind) || "audio",
      target_seconds: (params.dig(:session, :target_seconds) || 30).to_i,
      processing_state: "pending"
    )

    # Attach the media file
    @trial_session.media_files.attach(uploaded_file)

    # Store trial token in cookie for onboarding flow (expires in 1 hour)
    cookies[:demo_trial_token] = {
      value: @trial_session.token,
      expires: 1.hour.from_now,
      httponly: false  # Allow JavaScript access if needed
    }

    # Start background processing
    Sessions::TrialProcessJob.perform_later(@trial_session.token)

    # Handle AJAX vs traditional requests
    if request.xhr?
      render json: {
        success: true,
        trial_token: @trial_session.token,
        redirect_url: trial_session_path(@trial_session.token),
        message: "Recording uploaded! Your analysis will be ready shortly."
      }, status: :created
    else
      # Redirect to trial analysis page
      redirect_to trial_session_path(@trial_session.token),
                  notice: "Recording uploaded! Your analysis will be ready shortly."
    end
  end

  def process_trial_audio(uploaded_file)
    begin
      # Check if Deepgram API key is available
      if ENV["DEEPGRAM_API_KEY"].blank?
        Rails.logger.error "Trial processing failed: Deepgram API key not configured"
        # For demo purposes, return basic mock results
        return {
          success: true,
          wpm: 150,
          filler_count: 2,
          transcript: "This is a demo transcription showing basic speech analysis results.",
          duration_seconds: 30,
          demo_mode: true
        }
      end

      # Use existing STT service for transcription
      stt_client = Stt::DeepgramClient.new
      transcript_result = stt_client.transcribe_file(uploaded_file.tempfile.path)

      # Extract data from successful transcription
      transcript = transcript_result[:transcript]
      words = transcript_result[:words] || []
      duration_seconds = transcript_result.dig(:metadata, :duration) || 30

      # Validate transcription quality
      if transcript.blank? || words.empty?
        return {
          success: false,
          error: "No speech detected in recording. Please ensure you spoke clearly and try again."
        }
      end

      # Calculate basic metrics
      wpm = calculate_trial_wpm(words)
      filler_count = count_trial_fillers(transcript)

      {
        success: true,
        wpm: wpm,
        filler_count: filler_count,
        transcript: transcript,
        duration_seconds: duration_seconds
      }
    rescue => e
      Rails.logger.error "Trial analysis error: #{e.message}"
      {
        success: false,
        error: "Analysis failed. Please try again."
      }
    end
  end

  def calculate_trial_wpm(words)
    return 0 if words.blank?

    # Simple WPM calculation for trial
    word_count = words.length
    # Words have :end key in milliseconds, convert to minutes
    duration_minutes = (words.last[:end] / 1000.0 / 60.0) rescue 0.5

    (word_count / duration_minutes).round
  end

  def count_trial_fillers(transcript)
    return 0 if transcript.blank?

    filler_words = %w[um uh er ah hmm like you-know so basically actually literally]
    filler_pattern = /\b(#{filler_words.join('|')})\b/i

    transcript.scan(filler_pattern).length
  end

  def prepare_progress_chart_data(sessions, time_range = "7")
    return {} if sessions.empty?

    # Filter sessions based on time range
    chart_sessions = case time_range
    when "7"
      sessions.last(7)
    when "30"
      sessions.last(30)
    when "lifetime"
      sessions
    else
      sessions.last(7)
    end

    # For lifetime view with many sessions, use session numbers
    # For smaller ranges, show relative session numbers
    labels = if chart_sessions.count > 30
      # For many sessions, show every Nth label to avoid crowding
      chart_sessions.map.with_index { |s, i| (i + 1) % 5 == 0 || i == 0 || i == chart_sessions.count - 1 ? "#{i + 1}" : "" }
    else
      chart_sessions.map.with_index { |s, i| "Session #{i + 1}" }
    end

    {
      labels: labels,
      # Overall score (primary metric)
      overall_score_data: chart_sessions.map { |s| (s.analysis_data["overall_score"].to_f * 100).round },
      # Primary metrics
      filler_data: chart_sessions.map { |s| (s.analysis_data["filler_rate"].to_f * 100).round(1) },
      pace_data: chart_sessions.map { |s| s.analysis_data["wpm"].to_f.round },
      clarity_data: chart_sessions.map { |s| (s.analysis_data["clarity_score"].to_f * 100).round },
      # Secondary metrics
      pace_consistency_data: chart_sessions.map { |s| (s.analysis_data["pace_consistency"].to_f * 100).round },
      fluency_data: chart_sessions.map { |s| (s.analysis_data["fluency_score"].to_f * 100).round },
      engagement_data: chart_sessions.map { |s| (s.analysis_data["engagement_score"].to_f * 100).round },
      time_range: time_range,
      session_count: chart_sessions.count
    }
  end

  def prepare_skill_snapshot_data(sessions)
    return {} if sessions.empty?

    # Prepare skill snapshot comparing last 5 sessions average to 30-day average
    # This provides a trend view: is the user improving relative to their baseline?
    # - Clarity: percentage score (higher is better)
    # - Filler rate: percentage of filler words (lower is better)
    # - Pace: words per minute
    # Delta shows improvement trend (green=improved, red=declined)

    # Recent performance: last 5 sessions (or all if < 5)
    recent_count = [ 5, sessions.count ].min
    recent_sessions = sessions.last(recent_count)

    # Baseline: all sessions (already filtered to 30 days in controller)
    baseline_sessions = sessions

    # Calculate recent averages
    recent_overall = calculate_session_average(recent_sessions, "overall_score")
    recent_clarity = calculate_session_average(recent_sessions, "clarity_score")
    recent_filler = calculate_session_average(recent_sessions, "filler_rate")
    recent_pace = calculate_session_average(recent_sessions, "wpm")
    recent_pace_consistency = calculate_session_average(recent_sessions, "pace_consistency")
    recent_fluency = calculate_session_average(recent_sessions, "fluency_score")
    recent_engagement = calculate_session_average(recent_sessions, "engagement_score")

    # Calculate baseline averages (30-day)
    baseline_overall = calculate_session_average(baseline_sessions, "overall_score")
    baseline_clarity = calculate_session_average(baseline_sessions, "clarity_score")
    baseline_filler = calculate_session_average(baseline_sessions, "filler_rate")
    baseline_pace = calculate_session_average(baseline_sessions, "wpm")
    baseline_pace_consistency = calculate_session_average(baseline_sessions, "pace_consistency")
    baseline_fluency = calculate_session_average(baseline_sessions, "fluency_score")
    baseline_engagement = calculate_session_average(baseline_sessions, "engagement_score")

    # Convert to display format and calculate deltas
    {
      overall_score: {
        score: (recent_overall * 100).round,
        delta: ((recent_overall - baseline_overall) * 100).round
      },
      clarity: {
        score: (recent_clarity * 100).round,
        delta: ((recent_clarity - baseline_clarity) * 100).round
      },
      filler_rate: {
        score: (recent_filler * 100).round(1),
        delta: ((recent_filler - baseline_filler) * 100).round(1)
      },
      pace: {
        score: recent_pace.round,
        delta: (recent_pace - baseline_pace).round
      },
      pace_consistency: {
        score: (recent_pace_consistency * 100).round,
        delta: ((recent_pace_consistency - baseline_pace_consistency) * 100).round
      },
      fluency: {
        score: (recent_fluency * 100).round,
        delta: ((recent_fluency - baseline_fluency) * 100).round
      },
      engagement: {
        score: (recent_engagement * 100).round,
        delta: ((recent_engagement - baseline_engagement) * 100).round
      }
    }
  end

  def calculate_session_average(sessions, metric_key)
    values = sessions.filter_map { |s| s.analysis_data[metric_key] }
    return 0 if values.empty?
    values.sum / values.count.to_f
  end

  def prepare_calendar_data(sessions)
    # Show full year (Jan 1 - Dec 31 of current year)
    days = []
    year_start = Date.new(Date.current.year, 1, 1)
    year_end = Date.new(Date.current.year, 12, 31)

    (year_start..year_end).each do |date|
      session_on_date = sessions.find { |s| s.created_at.to_date == date }

      days << {
        date: date,
        has_session: session_on_date.present?,
        session_count: sessions.count { |s| s.created_at.to_date == date }
      }
    end

    days
  end

  def calculate_weekly_focus_tracking(weekly_focus)
    return nil unless weekly_focus.present?

    today = Date.current
    user = weekly_focus.user

    # Sessions completed today for this weekly focus
    sessions_today = user.sessions
                                  .where(weekly_focus_id: weekly_focus.id)
                                  .where(completed: true)
                                  .where("DATE(created_at) = ?", today)
                                  .count

    # Sessions completed this week for this weekly focus
    sessions_this_week = user.sessions
                                     .where(weekly_focus_id: weekly_focus.id)
                                     .where(completed: true)
                                     .where("created_at >= ?", weekly_focus.week_start)
                                     .count

    # Calculate streak (consecutive days with completed sessions for this focus)
    streak = calculate_focus_streak(weekly_focus)

    # Target sessions per day (approximately)
    target_per_day = (weekly_focus.target_sessions_per_week.to_f / 7).ceil

    {
      sessions_today: sessions_today,
      target_today: target_per_day,
      sessions_this_week: sessions_this_week,
      target_this_week: weekly_focus.target_sessions_per_week,
      streak_days: streak,
      completion_percentage: weekly_focus.completion_percentage
    }
  end

  def calculate_focus_streak(weekly_focus)
    # Get all completed sessions for this weekly focus, ordered by date
    sessions = weekly_focus.user.sessions
                           .where(weekly_focus_id: weekly_focus.id)
                           .where(completed: true)
                           .where("created_at >= ?", weekly_focus.week_start)
                           .order(created_at: :desc)

    return 0 if sessions.empty?

    # Get unique dates with sessions
    session_dates = sessions.map { |s| s.created_at.to_date }.uniq.sort.reverse

    # Count consecutive days from today backwards
    streak = 0
    current_date = Date.current

    session_dates.each do |session_date|
      if session_date == current_date
        streak += 1
        current_date -= 1.day
      else
        break
      end
    end

    streak
  end

  def prepare_last_session_insight(session, priority_recommendations = nil)
    return nil unless session.present? && session.analysis_data.present?

    # Extract all metrics from the current session
    current_metrics = {
      overall_score: session.analysis_data["overall_score"],
      filler_rate: session.analysis_data["filler_rate"],
      clarity_score: session.analysis_data["clarity_score"],
      wpm: session.analysis_data["wpm"],
      pace_consistency: session.analysis_data["pace_consistency"],
      fluency_score: session.analysis_data["fluency_score"],
      engagement_score: session.analysis_data["engagement_score"]
    }

    # Get previous session for delta calculation
    previous_session = session.user.sessions
                               .where(completed: true)
                               .where("id < ?", session.id)
                               .order(created_at: :desc)
                               .first

    # Calculate deltas
    metrics_with_deltas = {}
    current_metrics.each do |key, value|
      prev_value = previous_session&.analysis_data&.dig(key.to_s)
      delta = if prev_value && value
        value - prev_value
      else
        nil
      end

      metrics_with_deltas[key] = {
        value: value,
        delta: delta
      }
    end

    # Identify what went well and what needs work (for narrative)
    strengths = []
    weaknesses = []

    filler_rate = current_metrics[:filler_rate]
    clarity_score = current_metrics[:clarity_score]
    wpm = current_metrics[:wpm]

    if filler_rate && filler_rate < 0.03
      strengths << "filler word control (#{(filler_rate * 100).round(1)}%)"
    elsif filler_rate && filler_rate > 0.05
      weaknesses << "filler word usage (#{(filler_rate * 100).round(1)}%)"
    end

    if clarity_score && clarity_score > 0.85
      strengths << "speech clarity (#{(clarity_score * 100).round}%)"
    elsif clarity_score && clarity_score < 0.70
      weaknesses << "speech clarity (#{(clarity_score * 100).round}%)"
    end

    if wpm && wpm >= 130 && wpm <= 170
      strengths << "natural pace (#{wpm.round} WPM)"
    elsif wpm && (wpm < 110 || wpm > 190)
      weaknesses << "speaking pace (#{wpm.round} WPM)"
    end

    # Generate narrative
    narrative = if strengths.any? && weaknesses.any?
      "You excelled at #{strengths.join(', ')}, but let's work on #{weaknesses.join(', ')}."
    elsif strengths.any?
      "Great session! You showed strong #{strengths.join(', ')}. Keep it up!"
    elsif weaknesses.any?
      "Let's focus on improving #{weaknesses.join(', ')} in your next sessions."
    else
      "Solid session. Keep practicing to see continued improvement."
    end

    # Extract secondary observations from priority recommendations
    secondary_observations = if priority_recommendations && priority_recommendations[:secondary_focus]
      priority_recommendations[:secondary_focus].take(2) # Limit to 2 observations
    else
      []
    end

    {
      session: session,
      narrative: narrative,
      date: session.created_at,
      key_metrics: metrics_with_deltas,
      secondary_observations: secondary_observations
    }
  end

  def calculate_progress_percent(session)
    case session.processing_state
    when "pending" then 5
    when "processing"
      # Estimate based on time elapsed
      processing_duration = Time.current - session.updated_at
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
      processing_duration = Time.current - session.updated_at
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

  def activate_trial_if_requested
    if params[:trial] == "true" && !logged_in?
      activate_trial
    end
  end

  # Helper methods for mobile API progress endpoint
  def extract_current_values(sessions)
    return {} if sessions.empty?

    latest = sessions.last
    return {} unless latest&.analysis_data

    {
      overall_score: latest.analysis_data["overall_score"],
      filler_rate: latest.analysis_data["filler_rate"],
      pace_wpm: latest.analysis_data["pace_wpm"],
      clarity_score: latest.analysis_data["clarity_score"],
      fluency_score: latest.analysis_data["fluency_score"],
      engagement_score: latest.analysis_data["engagement_score"],
      pace_consistency: latest.analysis_data["pace_consistency"]
    }
  end

  def extract_best_values(sessions)
    return {} if sessions.empty?

    {
      overall_score: sessions.maximum("(analysis_json->>'overall_score')::float"),
      filler_rate: sessions.minimum("(analysis_json->>'filler_rate')::float"),
      pace_wpm: sessions.maximum("(analysis_json->>'pace_wpm')::float"),
      clarity_score: sessions.maximum("(analysis_json->>'clarity_score')::float"),
      fluency_score: sessions.maximum("(analysis_json->>'fluency_score')::float"),
      engagement_score: sessions.maximum("(analysis_json->>'engagement_score')::float"),
      pace_consistency: sessions.maximum("(analysis_json->>'pace_consistency')::float")
    }
  rescue => e
    Rails.logger.error "Error extracting best values: #{e.message}"
    {}
  end

  def extract_trends(sessions)
    return {} if sessions.length < 2

    recent_5 = sessions.last(5)
    previous_5 = sessions.length > 5 ? sessions[-10..-6] || [] : []

    return {} if recent_5.empty?

    metrics = [:overall_score, :filler_rate, :pace_wpm, :clarity_score, :fluency_score, :engagement_score, :pace_consistency]
    trends = {}

    metrics.each do |metric|
      recent_avg = recent_5.map { |s| s.analysis_data[metric.to_s].to_f }.compact.sum / recent_5.length

      if previous_5.any?
        prev_avg = previous_5.map { |s| s.analysis_data[metric.to_s].to_f }.compact.sum / previous_5.length
        trends[metric] = recent_avg > prev_avg ? 'up' : (recent_avg < prev_avg ? 'down' : 'neutral')
      else
        trends[metric] = 'neutral'
      end
    end

    trends
  rescue => e
    Rails.logger.error "Error extracting trends: #{e.message}"
    {}
  end

  def extract_deltas(sessions)
    return {} if sessions.length < 2

    latest = sessions.last
    previous = sessions[-2]

    return {} unless latest&.analysis_data && previous&.analysis_data

    {
      overall_score: (latest.analysis_data["overall_score"].to_f - previous.analysis_data["overall_score"].to_f).round(1),
      filler_rate: (latest.analysis_data["filler_rate"].to_f - previous.analysis_data["filler_rate"].to_f).round(1),
      pace_wpm: (latest.analysis_data["pace_wpm"].to_f - previous.analysis_data["pace_wpm"].to_f).round(1),
      clarity_score: (latest.analysis_data["clarity_score"].to_f - previous.analysis_data["clarity_score"].to_f).round(1)
    }
  rescue => e
    Rails.logger.error "Error extracting deltas: #{e.message}"
    {}
  end
end
