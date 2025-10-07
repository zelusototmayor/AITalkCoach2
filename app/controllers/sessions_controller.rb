class SessionsController < ApplicationController
  before_action :require_login, except: [:index, :create]
  before_action :require_login_or_trial, only: [:index, :create]
  before_action :set_session, only: [:show, :destroy]
  
  def index
    # Handle trial activation
    if params[:trial] == 'true' && !logged_in?
      activate_trial
      # Note: Analytics tracking for trial_started happens on the frontend when user clicks the trial button
    end

    if trial_mode?
      # Trial mode: simplified interface
      @trial_prompt = "Describe your biggest professional challenge and how you're tackling it. Keep it under 30 seconds."
      @default_prompt = @trial_prompt
      @default_prompt_data = { prompt: @trial_prompt, target_seconds: 30 }

      # Check for trial results to display
      if params[:trial_results] == 'true' && session[:trial_results]
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
    else
      # Regular authenticated flow
      # Note: Analytics tracking for real_session_started happens on the frontend
      @prompts = load_prompts_from_config
      @adaptive_prompts = get_adaptive_prompts
      @categories = (@prompts.keys + ['recommended']).uniq.sort
      @user_weaknesses = analyze_user_weaknesses

      # Quick metrics for insights panel
      @recent_sessions = current_user.sessions
                                     .where(completed: true)
                                     .where('sessions.created_at > ?', 30.days.ago)
                                     .order('sessions.created_at DESC')
                                     .limit(10)
                                     .includes(:issues)

      @quick_metrics = calculate_quick_metrics(@recent_sessions)
      @focus_areas = generate_focus_areas
      @current_streak = calculate_current_streak
      @enforcement_analytics = calculate_enforcement_analytics

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

  def progress
    # Get recent sessions for progress tracking (last 30 days)
    @recent_sessions = current_user.sessions
                                   .where(completed: true)
                                   .where('sessions.created_at > ?', 30.days.ago)
                                   .order('sessions.created_at ASC')  # ASC for chronological charts
                                   .includes(:issues)

    # Get the most recent completed session for recommendations
    @latest_session = @recent_sessions.last  # Changed from first since we're sorting ASC

    # Generate priority recommendations if we have a recent session
    if @latest_session
      begin
        user_context = {
          speech_context: @latest_session.speech_context || 'general',
          historical_sessions: @recent_sessions.to_a
        }
        recommender = Analysis::PriorityRecommender.new(@latest_session, user_context)
        @priority_recommendations = recommender.generate_priority_recommendations
      rescue => e
        Rails.logger.error "Priority recommendations error: #{e.message}"
        @priority_recommendations = nil
      end
    end

    # Prepare chart data for frontend
    @chart_data = prepare_progress_chart_data(@recent_sessions)

    # Prepare skill snapshot data (current vs previous session)
    @skill_snapshot = prepare_skill_snapshot_data(@recent_sessions)

    # Prepare calendar data (last 30 days)
    @calendar_data = prepare_calendar_data(@recent_sessions)
  end
  
  
  def create
    if trial_mode?
      # Handle trial session - no DB persistence
      handle_trial_session
    else
      # Regular authenticated session
      @session = current_user.sessions.build(session_params)
      @session.processing_state = 'pending'
      @session.completed = false

      # Set enforcement flag based on whether it's coming from practice interface
      # If not explicitly set, default to true for practice interface sessions
      if @session.minimum_duration_enforced.nil?
        @session.minimum_duration_enforced = true
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
            message: 'Recording session created successfully. Analysis will be available shortly.'
          }, status: :created
        else
          # Traditional request - redirect as before
          redirect_to @session, notice: 'Recording session created successfully. Analysis will be available shortly.'
        end
      else
        # Handle validation errors
        if request.xhr?
          # AJAX request - return error response with detailed error info
          error_messages = @session.errors.full_messages
          primary_message = if error_messages.any?
            error_messages.first
          else
            'Please record audio before submitting'
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
          @categories = (@prompts.keys + ['recommended']).uniq.sort
          @user_weaknesses = analyze_user_weaknesses
          render :index, status: :unprocessable_content
        end
      end
    end
  end
  
  def show
    @issues = @session.issues.order(:start_ms)

    # Generate priority-based recommendations for completed sessions
    if @session.completed? && @session.analysis_data.present?
      begin
        # Get last 5 sessions for historical context
        recent_sessions = current_user.sessions
          .where(completed: true)
          .where('id <= ?', @session.id) # Include current + previous
          .order(created_at: :desc)
          .limit(5)
          .includes(:issues)

        user_context = {
          speech_context: @session.speech_context || params[:context] || 'general',
          historical_sessions: recent_sessions.to_a
        }
        recommender = Analysis::PriorityRecommender.new(@session, user_context)
        @priority_recommendations = recommender.generate_priority_recommendations
      rescue => e
        Rails.logger.error "Priority recommendations error: #{e.message}"
        @priority_recommendations = nil
      end
    end

    # Set appropriate flash message based on session state
    if @session.processing_state == 'pending'
      flash.now[:info] = 'Your session is being processed. Analysis results will appear automatically when ready.'
    elsif @session.processing_state == 'failed'
      flash.now[:alert] = 'Session analysis failed. Please try re-processing or contact support.'
    elsif @session.processing_state == 'completed' && @session.analysis_data.present?
      flash.now[:success] = 'Analysis complete! Review your detailed feedback below.' if params[:notice].blank?
    end

    # Prepare sessions data for insights controller
    begin
      @user_sessions = current_user.sessions
                                    .where(completed: true)
                                    .where('sessions.created_at > ?', 90.days.ago)
                                    .order('sessions.created_at DESC')
                                    .limit(50)
                                    .includes(:issues)
                                    .map do |session|
        {
          id: session.id,
          created_at: session.created_at&.iso8601,
          analysis_data: session.analysis_data || {},
          duration: (session.analysis_data&.dig('duration_seconds')&.to_f rescue 0),
          metrics: {
            clarity_score: (session.analysis_data&.dig('clarity_score')&.to_f rescue nil),
            wpm: (session.analysis_data&.dig('wpm')&.to_f rescue nil),
            filler_rate: (session.analysis_data&.dig('filler_rate')&.to_f rescue nil),
            pace_consistency: (session.analysis_data&.dig('pace_consistency')&.to_f rescue nil),
            volume_consistency: (session.analysis_data&.dig('speech_to_silence_ratio')&.to_f rescue nil),
            engagement_score: (session.analysis_data&.dig('engagement_score')&.to_f rescue nil),
            fluency_score: (session.analysis_data&.dig('fluency_score')&.to_f rescue nil),
            overall_score: (session.analysis_data&.dig('overall_score')&.to_f rescue nil)
          }
        }
      end
    rescue => e
      Rails.logger.error "Error preparing sessions data for insights: #{e.message}"
      @user_sessions = []
    end
  end
  
  def destroy
    @session.destroy
    redirect_to practice_path, notice: 'Session deleted successfully.'
  end
  
  # Make the helper methods available to views
  helper_method :normalize_metric_for_display, :humanize_improvement_type, :format_metric_value, :format_effort_level

  private

  def set_session
    @session = current_user.sessions.find(params[:id])
  end

  # Helper method to convert decimal metrics to percentage for display
  def normalize_metric_for_display(session, metric_key)
    value = session.analysis_data[metric_key]
    return nil unless value.present?

    # All metrics are now consistently stored as decimals (0.85 = 85%)
    case metric_key
    when 'filler_rate', 'clarity_score', 'fluency_score', 'engagement_score', 'pace_consistency', 'overall_score'
      (value * 100).round(1)
    else
      value
    end
  end

  def humanize_improvement_type(type)
    case type
    when 'reduce_fillers' then 'Reduce Filler Words'
    when 'improve_pace' then 'Improve Speaking Pace'
    when 'enhance_clarity' then 'Enhance Speech Clarity'
    when 'boost_engagement' then 'Boost Engagement'
    when 'increase_fluency' then 'Increase Fluency'
    when 'fix_long_pauses' then 'Fix Long Pauses'
    when 'professional_language' then 'Use Professional Language'
    else type.humanize
    end
  end

  def format_metric_value(value, type)
    case type
    when 'reduce_fillers'
      "#{(value * 100).round(1)}%"
    when 'improve_pace'
      "#{value.round} WPM"
    when 'enhance_clarity', 'boost_engagement', 'increase_fluency'
      "#{(value * 100).round}%"
    when 'fix_long_pauses'
      "#{value} pauses"
    when 'professional_language'
      "#{value} issues"
    else
      value.to_s
    end
  end

  def format_effort_level(level)
    case level
    when 1 then 'Easy'
    when 2 then 'Moderate'
    when 3 then 'Hard'
    when 4 then 'Very Hard'
    else 'Unknown'
    end
  end

  
  def session_params
    params.require(:session).permit(:title, :language, :media_kind, :target_seconds, :minimum_duration_enforced, :speech_context, media_files: [])
  end
  
  def extract_session_metrics(session)
    return {} unless session.analysis_data.present?
    
    analysis = session.analysis_data
    issues_count = session.issues.count
    
    {
      clarity_score: analysis['clarity_score'] || calculate_clarity_from_issues(session),
      words_per_minute: analysis['wpm'],
      filler_rate: analysis['filler_rate'],
      pace_consistency: calculate_pace_consistency(session),
      volume_consistency: calculate_volume_consistency(session),
      engagement_score: calculate_engagement_score(session)
    }.compact
  end
  
  def calculate_clarity_from_issues(session)
    return nil unless session.duration_ms && session.duration_ms > 0
    
    total_issue_duration = session.issues.sum(&:duration_ms) || 0
    clarity_score = 1.0 - (total_issue_duration.to_f / session.duration_ms)
    [clarity_score, 0.0].max
  end
  
  def calculate_pace_consistency(session)
    return nil unless session.analysis_data['wpm']
    
    # Simple consistency measure - would be enhanced with actual variance calculation
    wpm = session.analysis_data['wpm'].to_f
    ideal_wpm = 150.0
    deviation = (wpm - ideal_wpm).abs / ideal_wpm
    consistency = 1.0 - [deviation, 1.0].min
    [consistency, 0.0].max
  end
  
  def calculate_volume_consistency(session)
    # Placeholder for volume analysis - would analyze audio amplitude variance
    0.8
  end
  
  def calculate_engagement_score(session)
    return nil unless session.analysis_data['clarity_score'] && session.analysis_data['wpm']
    
    clarity = session.analysis_data['clarity_score'].to_f
    wpm_score = [session.analysis_data['wpm'].to_f / 150.0, 1.0].min
    filler_penalty = (session.analysis_data['filler_rate'] || 0) * 2
    
    engagement = (clarity + wpm_score - filler_penalty) / 2.0
    [[engagement, 0.0].max, 1.0].min
  end

  def load_prompts_from_config
    begin
      config = YAML.load_file(Rails.root.join('config', 'prompts.yml'))
      base_prompts = config['base_prompts'] || {}
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
    
    config = YAML.load_file(Rails.root.join('config', 'prompts.yml'))
    weaknesses = analyze_user_weaknesses
    
    return {} if weaknesses.empty?
    
    adaptive_prompts = {}
    
    weaknesses.each do |weakness|
      if config['adaptive_prompts'][weakness]
        adaptive_prompts[weakness] = config['adaptive_prompts'][weakness]
      end
    end
    
    adaptive_prompts
  end
  
  def analyze_user_weaknesses
    return [] unless current_user
    
    # Get recent sessions for analysis
    recent_sessions = current_user.sessions
      .where(completed: true)
      .where('sessions.created_at >= ?', 30.days.ago)
      .includes(:issues)
    
    return [] if recent_sessions.count < 3
    
    config = YAML.load_file(Rails.root.join('config', 'prompts.yml'))
    thresholds = config['recommendation_settings']['issue_thresholds']
    
    weaknesses = []
    session_count = recent_sessions.count.to_f
    
    # Analyze filler words
    filler_sessions = recent_sessions.select do |session|
      session.issues.any? { |issue| issue.category == 'filler_words' }
    end
    if (filler_sessions.count / session_count) >= thresholds['filler_words']
      weaknesses << 'filler_words'
    end
    
    # Analyze pace issues
    pace_sessions = recent_sessions.select do |session|
      wpm = session.analysis_data['wpm']
      wpm && (wpm < 120 || wpm > 200)
    end
    if (pace_sessions.count / session_count) >= thresholds['pace_issues']
      weaknesses << 'pace_issues'
    end
    
    # Analyze clarity issues
    clarity_sessions = recent_sessions.select do |session|
      clarity = session.analysis_data['clarity_score']
      clarity && clarity < 0.7
    end
    if (clarity_sessions.count / session_count) >= thresholds['clarity_issues']
      weaknesses << 'clarity_issues'
    end
    
    # Analyze confidence issues (based on volume and filler frequency)
    confidence_sessions = recent_sessions.select do |session|
      filler_rate = session.analysis_data['filler_rate']
      issue_count = session.issues.count
      duration_seconds = (session.duration_ms || 0) / 1000.0
      
      (filler_rate && filler_rate > 0.05) || (duration_seconds > 0 && issue_count / duration_seconds > 0.1)
    end
    if (confidence_sessions.count / session_count) >= thresholds['confidence_issues']
      weaknesses << 'confidence_issues'
    end
    
    # Analyze engagement issues (based on monotone speech patterns)
    engagement_sessions = recent_sessions.select do |session|
      clarity = session.analysis_data['clarity_score']
      wpm = session.analysis_data['wpm']
      # Simple heuristic: low variation in metrics suggests low engagement
      clarity && wpm && clarity < 0.8 && (wpm < 140 || wpm > 180)
    end
    if (engagement_sessions.count / session_count) >= thresholds['engagement_issues']
      weaknesses << 'engagement_issues'
    end
    
    weaknesses.uniq
  end

  def calculate_quick_metrics(sessions)
    return {} if sessions.empty?

    # Use caching for expensive calculations
    # Get the latest updated_at from sessions without the join to avoid ambiguity
    latest_update = current_user.sessions
                                 .where(id: sessions.map(&:id))
                                 .maximum('sessions.updated_at')
    cache_key = "user_#{current_user.id}_quick_metrics_#{latest_update&.to_i}"

    Rails.cache.fetch(cache_key, expires_in: 15.minutes) do
      total_sessions = sessions.count
      wpm_values = sessions.filter_map { |s| s.analysis_data['wpm'] }
      filler_values = sessions.filter_map { |s| s.analysis_data['filler_rate'] }
      clarity_values = sessions.filter_map { |s| s.analysis_data['clarity_score'] }

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
      'filler_words' => 'Reduce filler words below 3% using pause drills',
      'pace_issues' => 'Target 140-170 WPM in 60s sessions',
      'clarity_issues' => 'Practice concise answers (30s prompts)',
      'confidence_issues' => 'Build confidence with storytelling prompts',
      'engagement_issues' => 'Add energy and vary vocal tone'
    }

    @user_weaknesses.map { |weakness| focus_recommendations[weakness] }.compact
  end

  def calculate_current_streak
    # Cache streak calculation since it's expensive and doesn't change often
    cache_key = "user_#{current_user.id}_current_streak_#{Date.current.to_s}"

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
                                    .where('sessions.created_at > ?', 30.days.ago)

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
    return 'stable' if sessions.count < 6

    # Compare recent vs earlier completion rates
    half_point = sessions.count / 2
    recent_sessions = sessions.limit(half_point)
    earlier_sessions = sessions.offset(half_point)

    recent_rate = recent_sessions.where(completed: true).count.to_f / recent_sessions.count
    earlier_rate = earlier_sessions.where(completed: true).count.to_f / earlier_sessions.count

    if recent_rate > earlier_rate + 0.1
      'improving'
    elsif recent_rate < earlier_rate - 0.1
      'declining'
    else
      'stable'
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
            prompt: first_prompt['prompt'],
            target_seconds: first_prompt['target_seconds'] || 60,
            title: first_prompt['title'],
            description: first_prompt['description']
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
            prompt: first_prompt['prompt'],
            target_seconds: first_prompt['target_seconds'] || 60,
            title: first_prompt['title'],
            description: first_prompt['description']
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
        prompt: selected_prompt['prompt'],
        target_seconds: selected_prompt['target_seconds'] || 60,
        title: selected_prompt['title'],
        description: selected_prompt['description']
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
    parts = prompt_id.split('_')
    return get_default_prompt_data unless parts.length >= 2

    category = parts[0..-2].join('_')  # Handle category names with underscores
    index = parts[-1].to_i

    return get_default_prompt_data unless @prompts[category]

    prompts = @prompts[category]
    return get_default_prompt_data unless prompts.is_a?(Array) && prompts[index]

    selected_prompt = prompts[index]
    if selected_prompt.is_a?(Hash)
      {
        prompt: selected_prompt['prompt'],
        target_seconds: selected_prompt['target_seconds'] || 60,
        title: selected_prompt['title'],
        description: selected_prompt['description']
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

  # Trial mode helpers
  def require_login_or_trial
    return if logged_in?

    # Allow trial access if trial parameter is present or trial is already active
    if params[:trial] == 'true' || trial_mode?
      return
    end

    # Otherwise require login
    store_location
    redirect_to login_path, alert: 'Please login or try our demo'
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

      error_message = 'Please record audio before submitting'
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

      error_message = 'Recording file is empty. Please record again.'
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
      language: params.dig(:session, :language) || 'en',
      media_kind: params.dig(:session, :media_kind) || 'audio',
      target_seconds: (params.dig(:session, :target_seconds) || 30).to_i,
      processing_state: 'pending'
    )

    # Attach the media file
    @trial_session.media_files.attach(uploaded_file)

    # Start background processing
    Sessions::TrialProcessJob.perform_later(@trial_session.token)

    # Handle AJAX vs traditional requests
    if request.xhr?
      render json: {
        success: true,
        trial_token: @trial_session.token,
        redirect_url: trial_session_path(@trial_session.token),
        message: 'Recording uploaded! Your analysis will be ready shortly.'
      }, status: :created
    else
      # Redirect to trial analysis page
      redirect_to trial_session_path(@trial_session.token),
                  notice: 'Recording uploaded! Your analysis will be ready shortly.'
    end
  end

  def process_trial_audio(uploaded_file)
    begin
      # Check if Deepgram API key is available
      if ENV['DEEPGRAM_API_KEY'].blank?
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

  def prepare_progress_chart_data(sessions)
    return {} if sessions.empty?

    # Limit to last 7 sessions for chart readability
    chart_sessions = sessions.last(7)

    {
      labels: chart_sessions.map { |s| "Session #{chart_sessions.index(s) + 1}" },
      filler_data: chart_sessions.map { |s| (s.analysis_data['filler_rate'].to_f * 100).round(1) },
      pace_data: chart_sessions.map { |s| s.analysis_data['wpm'].to_f.round },
      clarity_data: chart_sessions.map { |s| (s.analysis_data['clarity_score'].to_f * 100).round }
    }
  end

  def prepare_skill_snapshot_data(sessions)
    return {} if sessions.empty?

    current_session = sessions.last
    previous_session = sessions[-2] if sessions.length > 1

    current_clarity = (current_session.analysis_data['clarity_score'].to_f * 100).round
    current_filler = current_session.analysis_data['filler_rate'].to_f * 100
    current_pace = current_session.analysis_data['wpm'].to_f.round

    if previous_session
      prev_clarity = (previous_session.analysis_data['clarity_score'].to_f * 100).round
      prev_filler = previous_session.analysis_data['filler_rate'].to_f * 100
      prev_pace = previous_session.analysis_data['wpm'].to_f.round

      {
        clarity: { score: current_clarity, delta: current_clarity - prev_clarity },
        filler_control: { score: (100 - current_filler).round, delta: ((100 - current_filler) - (100 - prev_filler)).round(1) },
        pace: { score: current_pace, delta: current_pace - prev_pace }
      }
    else
      {
        clarity: { score: current_clarity, delta: 0 },
        filler_control: { score: (100 - current_filler).round, delta: 0 },
        pace: { score: current_pace, delta: 0 }
      }
    end
  end

  def prepare_calendar_data(sessions)
    # Get last 30 days
    days = []
    30.times do |i|
      date = Date.current - i.days
      session_on_date = sessions.find { |s| s.created_at.to_date == date }

      days << {
        date: date,
        has_session: session_on_date.present?,
        session_count: sessions.count { |s| s.created_at.to_date == date }
      }
    end

    days.reverse
  end

end