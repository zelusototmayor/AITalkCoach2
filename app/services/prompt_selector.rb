class PromptSelector
  def initialize(user)
    @user = user
    @config = load_prompts_config
  end

  # Get the daily prompt for the user based on their weekly focus
  # Returns next uncompleted prompt in their focus area
  def daily_prompt
    # Get user's current weekly focus
    weekly_focus = WeeklyFocus.current_for_user(@user)

    if weekly_focus && weekly_focus.focus_type.present?
      # Get prompts for the focus area
      focus_prompts = prompts_for_focus_type(weekly_focus.focus_type)

      # Find next uncompleted prompt
      next_prompt = next_uncompleted_prompt(focus_prompts)

      # If all focus prompts completed, fall back to general prompts
      return next_prompt if next_prompt
    end

    # Fallback to general prompts
    general_prompt
  end

  # Get a random prompt from ALL prompts (for shuffle)
  def shuffle_prompt(exclude_recent: true)
    all_prompts_list = all_prompts

    if exclude_recent
      # Exclude last 10 recently shown prompts (stored in session or could be tracked)
      # For now, just return random
      all_prompts_list.sample
    else
      all_prompts_list.sample
    end
  end

  # Mark a prompt as completed
  def self.mark_completed(user, prompt_identifier, session_id = nil)
    PromptCompletion.find_or_create_by!(
      user: user,
      prompt_identifier: prompt_identifier
    ) do |completion|
      completion.completed_at = Time.current
      completion.session_id = session_id
    end
  rescue ActiveRecord::RecordNotUnique
    # Already completed, ignore
    Rails.logger.info "Prompt #{prompt_identifier} already completed by user #{user.id}"
  end

  private

  def load_prompts_config
    @config ||= YAML.load_file(Rails.root.join("config", "prompts.yml"))
  rescue => e
    Rails.logger.error "Failed to load prompts config: #{e.message}"
    { "base_prompts" => {}, "adaptive_prompts" => {} }
  end

  # Get all prompts as a flat array with identifiers
  def all_prompts
    prompts = []

    # Add base prompts
    if @config["base_prompts"].is_a?(Hash)
      @config["base_prompts"].each do |category, category_prompts|
        next unless category_prompts.is_a?(Array)

        category_prompts.each_with_index do |prompt, index|
          prompts << format_prompt(prompt, category, index)
        end
      end
    end

    # Add adaptive prompts
    if @config["adaptive_prompts"].is_a?(Hash)
      @config["adaptive_prompts"].each do |category, category_prompts|
        next unless category_prompts.is_a?(Array)

        category_prompts.each_with_index do |prompt, index|
          prompts << format_prompt(prompt, category, index, adaptive: true)
        end
      end
    end

    prompts
  end

  # Get prompts for a specific focus type (e.g., "reduce_fillers")
  def prompts_for_focus_type(focus_type)
    # Map focus types to adaptive_prompts categories
    category_mapping = {
      "reduce_fillers" => "filler_words",
      "improve_pace" => "pace_issues",
      "enhance_clarity" => "clarity_issues",
      "fix_long_pauses" => "pause_consistency",
      "boost_engagement" => "engagement_issues",
      "increase_fluency" => "fluency_issues"
    }

    category = category_mapping[focus_type]
    return [] unless category

    prompts = []
    adaptive_category_prompts = @config.dig("adaptive_prompts", category)

    if adaptive_category_prompts.is_a?(Array)
      adaptive_category_prompts.each_with_index do |prompt, index|
        prompts << format_prompt(prompt, category, index, adaptive: true)
      end
    end

    prompts
  end

  # Find the next uncompleted prompt from a list
  def next_uncompleted_prompt(prompts)
    completed_ids = @user.prompt_completions.pluck(:prompt_identifier)

    # Find first uncompleted prompt
    prompts.find { |p| !completed_ids.include?(p[:identifier]) }
  end

  # Get a general prompt (fallback)
  def general_prompt
    # Get all prompts and find an uncompleted one, or return first
    all_prompts_list = all_prompts
    next_uncompleted_prompt(all_prompts_list) || all_prompts_list.first || default_fallback_prompt
  end

  # Format a prompt hash with all necessary fields
  def format_prompt(prompt, category, index, adaptive: false)
    # Handle both string and hash formats
    if prompt.is_a?(String)
      {
        identifier: "#{category}_#{index}",
        text: prompt,
        title: "Practice Prompt",
        category: category.humanize,
        difficulty: "intermediate",
        duration: 60,
        focus_areas: [],
        adaptive: adaptive
      }
    else
      {
        identifier: "#{category}_#{index}",
        text: prompt["prompt"] || prompt["text"],
        title: prompt["title"] || "Practice Prompt",
        category: category.humanize,
        difficulty: prompt["difficulty"] || "intermediate",
        duration: prompt["target_seconds"] || 60,
        focus_areas: prompt["focus_areas"] || [],
        description: prompt["description"],
        adaptive: adaptive
      }
    end
  end

  # Absolute fallback if config fails
  def default_fallback_prompt
    {
      identifier: "fallback_default",
      text: "What trade-off did you make recently and why?",
      title: "Quick Question",
      category: "General",
      difficulty: "intermediate",
      duration: 60,
      focus_areas: [],
      adaptive: false
    }
  end
end
