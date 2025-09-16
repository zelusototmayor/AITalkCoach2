class SessionsController < ApplicationController
  before_action :set_guest_user
  before_action :set_session, only: [:show, :destroy]
  
  def index
    @sessions = @current_user.sessions.order(created_at: :desc)
  end
  
  def new
    @session = @current_user.sessions.build
    @prompts = load_prompts_from_config
    @adaptive_prompts = get_adaptive_prompts
    @categories = (@prompts.keys + ['recommended']).uniq.sort
    @user_weaknesses = analyze_user_weaknesses
  end
  
  def create
    @session = @current_user.sessions.build(session_params)
    @session.processing_state = 'pending'
    @session.completed = false
    
    if @session.save
      # Enqueue background job for processing
      Sessions::ProcessJob.perform_later(@session.id)
      redirect_to @session, notice: 'Recording session started successfully.'
    else
      @prompts = load_prompts_from_config
      @adaptive_prompts = get_adaptive_prompts
      @categories = (@prompts.keys + ['recommended']).uniq.sort
      @user_weaknesses = analyze_user_weaknesses
      render :new, status: :unprocessable_content
    end
  end
  
  def show
    @issues = @session.issues.order(:start_ms)
    # User sessions will be loaded via AJAX for better performance
  end
  
  def destroy
    @session.destroy
    redirect_to sessions_path, notice: 'Session deleted successfully.'
  end
  
  private
  
  def set_session
    return if @current_user.nil?
    @session = @current_user.sessions.find(params[:id])
  end
  
  def set_guest_user
    # For v1, we'll use the guest user
    @current_user = User.find_by(email: 'guest@aitalkcoach.local')
    
    if @current_user.nil?
      redirect_to root_path, alert: 'Guest user not found. Please run db:seed.'
      return false
    end
  end
  
  def session_params
    params.require(:session).permit(:title, :language, :media_kind, :target_seconds, media_files: [])
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
    return {} unless @current_user
    
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
    return [] unless @current_user
    
    # Get recent sessions for analysis
    recent_sessions = @current_user.sessions
      .where(completed: true)
      .where('created_at >= ?', 30.days.ago)
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
end