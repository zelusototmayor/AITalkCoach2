module Analysis
  class MicroTipGenerator
    # Impact and effort scores for prioritization
    IMPACT_HIGH = 3
    IMPACT_MEDIUM = 2
    IMPACT_LOW = 1

    EFFORT_LOW = 1
    EFFORT_MEDIUM = 2
    EFFORT_HIGH = 3

    MAX_TIPS = 3

    def initialize(metrics, coaching_insights, focus_areas = [], primary_recommendation_type = nil)
      @metrics = metrics
      @coaching_insights = coaching_insights
      @focus_areas = focus_areas || []
      @primary_recommendation_type = primary_recommendation_type
    end

    def generate_tips
      tips = []

      # Generate potential tips from different categories
      tips.concat(generate_pause_tips)
      tips.concat(generate_pace_tips)
      tips.concat(generate_energy_tips)
      tips.concat(generate_filler_tips)
      tips.concat(generate_fluency_tips)

      # Remove tips that duplicate focus areas and primary recommendation
      tips = deduplicate_with_focus_areas(tips)
      tips = deduplicate_with_primary_recommendation(tips)

      # Prioritize by impact/effort ratio (higher is better)
      tips = tips.sort_by { |tip| -tip[:priority_score] }

      # Return top tips
      tips.first(MAX_TIPS)
    end

    private

    def generate_pause_tips
      tips = []
      pause_patterns = @coaching_insights[:pause_patterns] || {}

      return tips if pause_patterns.empty?

      quality_score = @metrics.dig(:clarity_metrics, :pause_metrics, :pause_quality_score) || 100

      # Only suggest if there's room for improvement
      if quality_score < 70 && pause_patterns[:quality_breakdown] == "mostly_good_with_awkward_long_pauses"
        tips << {
          category: "pause_consistency",
          title: "Pause Consistency",
          icon: "🔄",
          description: build_pause_description(pause_patterns, quality_score),
          action: "Aim for 0.5-1 second pauses between thoughts",
          impact: IMPACT_MEDIUM,
          effort: EFFORT_LOW,
          priority_score: calculate_priority_score(IMPACT_MEDIUM, EFFORT_LOW),
          data: {
            long_pause_count: pause_patterns[:specific_issue],
            current_score: quality_score
          }
        }
      end

      tips
    end

    def generate_pace_tips
      tips = []
      pace_patterns = @coaching_insights[:pace_patterns] || {}

      return tips if pace_patterns.empty? || pace_patterns[:trajectory] == "insufficient_data"

      consistency = pace_patterns[:consistency] || 1.0
      trajectory = pace_patterns[:trajectory]

      # Suggest pace consistency improvement
      if consistency < 0.6 && trajectory != "consistent_throughout"
        tips << {
          category: "pace_consistency",
          title: "Pace Consistency",
          icon: "⚡",
          description: build_pace_description(pace_patterns, consistency),
          action: "Practice maintaining steady pace throughout your talk",
          impact: IMPACT_MEDIUM,
          effort: EFFORT_MEDIUM,
          priority_score: calculate_priority_score(IMPACT_MEDIUM, EFFORT_MEDIUM),
          data: {
            trajectory: trajectory,
            consistency: (consistency * 100).round,
            wpm_range: pace_patterns[:wpm_range]
          }
        }
      end

      tips
    end

    def generate_energy_tips
      tips = []
      energy_patterns = @coaching_insights[:energy_patterns] || {}

      return tips if energy_patterns.empty?

      # Only suggest if energy is notably low
      if energy_patterns[:needs_boost] && energy_patterns[:overall_level] < 40
        tips << {
          category: "energy",
          title: "Energy Level",
          icon: "⚡",
          description: "Your energy level is low (#{energy_patterns[:overall_level].round}/100). Adding vocal variety and emphasis can make your speech more engaging.",
          action: "Try using more varied intonation and emphasis on key points",
          impact: IMPACT_HIGH,
          effort: EFFORT_LOW,
          priority_score: calculate_priority_score(IMPACT_HIGH, EFFORT_LOW),
          data: {
            current_level: energy_patterns[:overall_level],
            engagement_elements: energy_patterns[:engagement_elements]
          }
        }
      end

      tips
    end

    def generate_filler_tips
      tips = []
      hesitation = @coaching_insights[:hesitation_analysis] || {}

      return tips if hesitation.empty?

      filler_rate = hesitation[:rate_percentage] || 0

      # Only suggest if filler rate is problematic (>5%)
      if filler_rate > 5 && hesitation[:most_common]
        tips << {
          category: "filler_words",
          title: "Reduce Filler Words",
          icon: "🎤",
          description: build_filler_description(hesitation, filler_rate),
          action: "Practice pausing silently instead of saying filler words",
          impact: IMPACT_HIGH,
          effort: EFFORT_MEDIUM,
          priority_score: calculate_priority_score(IMPACT_HIGH, EFFORT_MEDIUM),
          data: {
            filler_rate: filler_rate,
            most_common: hesitation[:most_common],
            locations: hesitation[:typical_locations]
          }
        }
      end

      tips
    end

    def generate_fluency_tips
      tips = []
      smoothness = @coaching_insights[:smoothness_breakdown] || {}

      return tips if smoothness.empty?

      # Only suggest if there's a clear primary issue
      if smoothness[:primary_issue] && smoothness[:word_flow_score] < 60
        tips << {
          category: "fluency",
          title: "Speech Fluency",
          icon: "💬",
          description: build_fluency_description(smoothness),
          action: "Practice completing thoughts smoothly without restarts",
          impact: IMPACT_MEDIUM,
          effort: EFFORT_MEDIUM,
          priority_score: calculate_priority_score(IMPACT_MEDIUM, EFFORT_MEDIUM),
          data: {
            primary_issue: smoothness[:primary_issue],
            word_flow_score: smoothness[:word_flow_score],
            hesitation_count: smoothness[:hesitation_count],
            restart_count: smoothness[:restart_count]
          }
        }
      end

      tips
    end

    def build_pause_description(pause_patterns, quality_score)
      specific = pause_patterns[:specific_issue]
      "Your pauses are somewhat erratic (#{quality_score.round}/100 consistency). " +
      "#{specific ? "#{specific.capitalize} disrupted your flow." : 'Some pauses feel awkward.'}"
    end

    def build_pace_description(pace_patterns, consistency)
      trajectory = pace_patterns[:trajectory]
      wpm_range = pace_patterns[:wpm_range]

      trajectory_text = case trajectory
      when "starts_slow_rushes_middle_settles"
        "You start slow (#{wpm_range[0]} WPM) then rush in the middle (#{wpm_range[1]} WPM)"
      when "starts_slow_accelerates"
        "You start slow and gradually accelerate"
      when "starts_fast_decelerates"
        "You start fast and slow down as you continue"
      else
        "Your pace varies significantly (#{wpm_range[0]}-#{wpm_range[1]} WPM)"
      end

      "#{trajectory_text}. Consistency: #{(consistency * 100).round}/100."
    end

    def build_filler_description(hesitation, filler_rate)
      most_common = hesitation[:most_common]
      locations = hesitation[:typical_locations]

      location_text = locations == "mostly_at_sentence_starts" ?
        "mostly when starting new thoughts" :
        "throughout your speech"

      "You use filler words at #{filler_rate.round(1)}% rate. " +
      "Most common: '#{most_common}' #{location_text}."
    end

    def build_fluency_description(smoothness)
      issue = smoothness[:primary_issue]

      issue_text = case issue
      when "frequent_hesitations"
        "You hesitate frequently (#{smoothness[:hesitation_count]} times)"
      when "frequent_restarts"
        "You restart sentences often (#{smoothness[:restart_count]} times)"
      when "irregular_pauses"
        "Your pauses are irregular and disrupt flow"
      when "choppy_word_delivery"
        "Your word delivery feels choppy"
      else
        "Your speech flow could be smoother"
      end

      "#{issue_text}. Flow score: #{smoothness[:word_flow_score].round}/100."
    end

    def calculate_priority_score(impact, effort)
      # Higher impact / lower effort = higher priority
      # Score ranges from ~0.33 (low impact, high effort) to 3.0 (high impact, low effort)
      (impact.to_f / effort.to_f).round(2)
    end

    def deduplicate_with_focus_areas(tips)
      # Remove tips whose category matches existing focus areas
      focus_categories = @focus_areas.map do |area|
        normalize_category(area)
      end

      tips.reject { |tip| focus_categories.include?(tip[:category]) }
    end

    def deduplicate_with_primary_recommendation(tips)
      # Remove tips that match the primary recommendation type
      return tips if @primary_recommendation_type.nil?

      primary_category = map_recommendation_to_category(@primary_recommendation_type)
      tips.reject { |tip| tip[:category] == primary_category }
    end

    def normalize_category(area_name)
      # Map focus area names to tip categories
      normalized = area_name.to_s.downcase.gsub(/[^a-z_]/, "_")

      case normalized
      when /filler|um|uh/
        "filler_words"
      when /pace|speed|wpm/
        "pace_consistency"
      when /pause/
        "pause_consistency"
      when /energy|enthusiasm/
        "energy"
      when /fluen|smooth|flow/
        "fluency"
      else
        normalized
      end
    end

    def map_recommendation_to_category(recommendation_type)
      # Map PriorityRecommender types to MicroTipGenerator categories
      case recommendation_type.to_s
      when "reduce_fillers"
        "filler_words"
      when "improve_pace"
        "pace_consistency"
      when "fix_long_pauses"
        "pause_consistency"
      when "boost_engagement"
        "energy"
      when "increase_fluency"
        "fluency"
      when "enhance_clarity"
        "fluency" # Clarity improvements often relate to fluency
      else
        recommendation_type.to_s
      end
    end
  end
end
