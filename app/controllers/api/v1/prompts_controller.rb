class Api::V1::PromptsController < Api::V1::BaseController
  # GET /api/v1/prompts
  def index
    prompts = flatten_all_prompts

    # Group by category for easier consumption
    prompts_by_category = prompts.group_by { |p| p[:category] }

    render json: {
      success: true,
      prompts: prompts,
      prompts_by_category: prompts_by_category,
      categories: prompts.map { |p| p[:category] }.uniq.sort
    }
  end

  private

  def flatten_all_prompts
    prompts = []
    config = YAML.load_file(Rails.root.join("config", "prompts.yml"))

    # Include base prompts
    base_categories = %w[presentation conversation storytelling practice_drills]
    base_categories.each do |category|
      next unless config["base_prompts"][category]

      config["base_prompts"][category].each_with_index do |prompt, index|
        prompts << {
          id: "#{category}_#{index}",
          category: humanize_category(category),
          title: prompt["title"],
          description: prompt["description"],
          prompt_text: prompt["prompt"],
          duration: prompt["target_seconds"],
          focus_areas: prompt["focus_areas"] || [],
          difficulty: prompt["difficulty"],
          tags: prompt["tags"] || [],
          is_adaptive: false
        }
      end
    end

    # Include adaptive prompts if user has weaknesses
    if current_user
      weaknesses = analyze_user_weaknesses
      weaknesses.each do |weakness|
        next unless config["adaptive_prompts"] && config["adaptive_prompts"][weakness]

        config["adaptive_prompts"][weakness].each_with_index do |prompt, index|
          prompts << {
            id: "adaptive_#{weakness}_#{index}",
            category: "Recommended",
            title: prompt["title"],
            description: prompt["description"],
            prompt_text: prompt["prompt"],
            duration: prompt["target_seconds"],
            focus_areas: prompt["focus_areas"] || [],
            difficulty: prompt["difficulty"],
            tags: prompt["tags"] || [],
            is_adaptive: true,
            adaptive_for: weakness
          }
        end
      end
    end

    prompts
  end

  def humanize_category(category)
    case category
    when "practice_drills"
      "Practice Drills"
    else
      category.titleize
    end
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

    weaknesses.uniq
  end
end
