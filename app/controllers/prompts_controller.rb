class PromptsController < ApplicationController
  before_action :require_login
  before_action :require_subscription

  def index
    @prompts = load_prompts_from_config
    @adaptive_prompts = get_adaptive_prompts
    @categories = (@prompts.keys + [ "recommended" ]).uniq.sort
    @user_weaknesses = analyze_user_weaknesses
    @duration_groups = group_prompts_by_duration
    @all_prompts_flat = flatten_all_prompts
  end

  private

  def load_prompts_from_config
    config = YAML.load_file(Rails.root.join("config", "prompts.yml"))
    config["base_prompts"] || {}
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
      .where("created_at >= ?", 30.days.ago)
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
      wpm && (wpm < 120 || wpm > 200)
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
      clarity && wpm && clarity < 0.8 && (wpm < 140 || wpm > 180)
    end
    if (engagement_sessions.count / session_count) >= thresholds["engagement_issues"]
      weaknesses << "engagement_issues"
    end

    weaknesses.uniq
  end

  def group_prompts_by_duration
    all_prompts = flatten_all_prompts

    {
      quick: all_prompts.select { |p| p[:target_seconds].to_i <= 45 },
      standard: all_prompts.select { |p| p[:target_seconds].to_i.between?(46, 75) },
      deep: all_prompts.select { |p| p[:target_seconds].to_i > 75 }
    }
  end

  def flatten_all_prompts
    prompts = []
    config = YAML.load_file(Rails.root.join("config", "prompts.yml"))

    # Include base prompts (excluding adaptive categories)
    base_categories = %w[presentation conversation storytelling practice_drills]
    base_categories.each do |category|
      next unless config["base_prompts"][category]

      config["base_prompts"][category].each_with_index do |prompt, index|
        prompts << prompt.merge(
          category: category,
          prompt_id: "#{category}_#{index}",
          is_adaptive: false
        )
      end
    end

    # Include adaptive prompts if user has weaknesses
    weaknesses = analyze_user_weaknesses
    weaknesses.each do |weakness|
      next unless config["adaptive_prompts"][weakness]

      config["adaptive_prompts"][weakness].each_with_index do |prompt, index|
        prompts << prompt.merge(
          category: weakness,
          prompt_id: "adaptive_#{weakness}_#{index}",
          is_adaptive: true
        )
      end
    end

    prompts
  end

  def filter_prompts_by_difficulty(prompts, difficulty)
    return prompts if difficulty.blank?
    prompts.select { |p| p[:difficulty] == difficulty }
  end

  def filter_prompts_by_tags(prompts, tags)
    return prompts if tags.blank?
    tag_array = tags.is_a?(String) ? tags.split(',') : tags
    prompts.select { |p| (p[:tags] & tag_array).any? }
  end

  def get_all_adaptive_prompts_for_weakness(weakness)
    config = YAML.load_file(Rails.root.join("config", "prompts.yml"))
    return [] unless config["adaptive_prompts"][weakness]

    config["adaptive_prompts"][weakness].map.with_index do |prompt, index|
      prompt.merge(
        category: weakness,
        prompt_id: "adaptive_#{weakness}_#{index}",
        is_adaptive: true
      )
    end
  end
end
