module Analysis
  class PriorityRecommender
    # Impact scoring weights for different improvement areas
    IMPACT_WEIGHTS = {
      overall_score_improvement: 0.4,    # How much this could improve overall score
      skill_transferability: 0.3,       # How much this skill applies to other areas
      effort_to_difficulty_ratio: 0.2,  # Easy wins get higher priority
      user_context_relevance: 0.1       # Relevance to user's stated goals
    }.freeze

    # Difficulty levels for different types of improvements
    DIFFICULTY_LEVELS = {
      'reduce_fillers' => 2,      # Moderate - requires practice and awareness
      'improve_pace' => 3,        # Hard - requires timing and rhythm practice
      'enhance_clarity' => 4,     # Very hard - requires articulation work
      'boost_engagement' => 3,    # Hard - requires energy and variety
      'increase_fluency' => 4,    # Very hard - requires extensive practice
      'fix_long_pauses' => 2,     # Moderate - awareness and preparation help
      'professional_language' => 1 # Easy - vocabulary substitution
    }.freeze

    def initialize(session, user_context = {})
      @session = session
      @user_context = user_context
      @historical_sessions = user_context[:historical_sessions] || [session]
      @analysis_data = session.analysis_data
      @issues = session.issues.includes(:session)
    end

    def generate_priority_recommendations
      return [] unless @analysis_data.present?

      # Special handling for first session - always prompt to record again for baseline
      if @historical_sessions.count == 1
        return {
          focus_this_week: [first_session_recommendation],
          secondary_focus: [],
          long_term_goals: [],
          quick_wins: [],
          practice_plan: {}
        }
      end

      improvement_areas = identify_improvement_areas
      prioritized_areas = calculate_priorities(improvement_areas)

      {
        focus_this_week: prioritized_areas.first(2),
        secondary_focus: prioritized_areas[2..4] || [],
        long_term_goals: prioritized_areas[5..-1] || [],
        quick_wins: identify_quick_wins(prioritized_areas),
        practice_plan: generate_practice_plan(prioritized_areas.first(3))
      }
    end

    private

    def identify_improvement_areas
      areas = []

      # Analyze each metric and identify specific improvement opportunities
      current_metrics = {
        filler_rate: @analysis_data['filler_rate'] || 0,
        clarity_score: @analysis_data['clarity_score'] || 0,
        fluency_score: @analysis_data['fluency_score'] || 0,
        engagement_score: @analysis_data['engagement_score'] || 0,
        pace_consistency: @analysis_data['pace_consistency'] || 0,
        overall_score: @analysis_data['overall_score'] || 0,
        wpm: @analysis_data['wpm'] || 0
      }

      # Filler words analysis
      if current_metrics[:filler_rate] > 0.03 # More than 3%
        avg_filler = calculate_historical_average('filler_rate')
        filler_trend = determine_trend(current_metrics[:filler_rate], avg_filler)
        severity = current_metrics[:filler_rate] > 0.07 ? 'high' : 'medium'
        areas << {
          type: 'reduce_fillers',
          current_value: current_metrics[:filler_rate],
          target_value: 0.02,
          historical_average: avg_filler,
          trend: filler_trend,
          sessions_analyzed: @historical_sessions.count,
          potential_improvement: calculate_filler_improvement_impact(current_metrics[:filler_rate]),
          severity: severity,
          specific_issues: extract_filler_issues
        }
      end

      # Pace analysis
      wpm = current_metrics[:wpm]
      if wpm < 140 || wpm > 180
        target_wpm = wpm < 140 ? 150 : 165
        areas << {
          type: 'improve_pace',
          current_value: wpm,
          target_value: target_wpm,
          potential_improvement: calculate_pace_improvement_impact(wpm, target_wpm),
          severity: wpm < 120 || wpm > 200 ? 'high' : 'medium',
          specific_issues: extract_pace_issues
        }
      end

      # Clarity analysis
      if current_metrics[:clarity_score] < 0.75
        areas << {
          type: 'enhance_clarity',
          current_value: current_metrics[:clarity_score],
          target_value: 0.85,
          potential_improvement: calculate_clarity_improvement_impact(current_metrics[:clarity_score]),
          severity: current_metrics[:clarity_score] < 0.60 ? 'high' : 'medium',
          specific_issues: extract_clarity_issues
        }
      end

      # Engagement analysis
      if current_metrics[:engagement_score] < 0.70
        areas << {
          type: 'boost_engagement',
          current_value: current_metrics[:engagement_score],
          target_value: 0.80,
          potential_improvement: calculate_engagement_improvement_impact(current_metrics[:engagement_score]),
          severity: current_metrics[:engagement_score] < 0.50 ? 'high' : 'medium',
          specific_issues: extract_engagement_issues
        }
      end

      # Fluency analysis
      if current_metrics[:fluency_score] < 0.75
        areas << {
          type: 'increase_fluency',
          current_value: current_metrics[:fluency_score],
          target_value: 0.85,
          potential_improvement: calculate_fluency_improvement_impact(current_metrics[:fluency_score]),
          severity: current_metrics[:fluency_score] < 0.60 ? 'high' : 'medium',
          specific_issues: extract_fluency_issues
        }
      end

      # Long pause analysis
      long_pause_count = @analysis_data['long_pause_count'] || 0
      if long_pause_count > 2
        areas << {
          type: 'fix_long_pauses',
          current_value: long_pause_count,
          target_value: 1,
          potential_improvement: calculate_pause_improvement_impact(long_pause_count),
          severity: long_pause_count > 5 ? 'high' : 'medium',
          specific_issues: extract_pause_issues
        }
      end

      # Professional language analysis
      unprofessional_issues = @issues.where(category: 'professional_issues').count
      if unprofessional_issues > 3
        areas << {
          type: 'professional_language',
          current_value: unprofessional_issues,
          target_value: 1,
          potential_improvement: calculate_professionalism_improvement_impact(unprofessional_issues),
          severity: unprofessional_issues > 6 ? 'high' : 'low',
          specific_issues: extract_professional_issues
        }
      end

      areas
    end

    def calculate_priorities(improvement_areas)
      improvement_areas.map do |area|
        priority_score = calculate_priority_score(area)
        area.merge(
          priority_score: priority_score,
          effort_level: DIFFICULTY_LEVELS[area[:type]] || 3,
          estimated_weeks: estimate_improvement_time(area),
          actionable_steps: generate_actionable_steps(area)
        )
      end.sort_by { |area| -area[:priority_score] }
    end

    def calculate_priority_score(area)
      # Overall score improvement potential
      overall_impact = area[:potential_improvement] * IMPACT_WEIGHTS[:overall_score_improvement]

      # Skill transferability (some skills help with others)
      transferability = calculate_transferability_score(area[:type]) * IMPACT_WEIGHTS[:skill_transferability]

      # Effort to difficulty ratio (quick wins score higher)
      difficulty = DIFFICULTY_LEVELS[area[:type]] || 3
      effort_ratio = (5.0 - difficulty) / 4.0 * IMPACT_WEIGHTS[:effort_to_difficulty_ratio]

      # User context relevance
      context_relevance = calculate_context_relevance(area[:type]) * IMPACT_WEIGHTS[:user_context_relevance]

      (overall_impact + transferability + effort_ratio + context_relevance) * 100
    end

    def calculate_transferability_score(improvement_type)
      # Some improvements help with multiple areas
      case improvement_type
      when 'reduce_fillers' then 0.8    # Helps with fluency, clarity, professionalism
      when 'enhance_clarity' then 0.9   # Helps with everything
      when 'improve_pace' then 0.7      # Helps with engagement and clarity
      when 'increase_fluency' then 0.6  # Helps with clarity and engagement
      when 'professional_language' then 0.5 # Mainly helps with professionalism
      when 'boost_engagement' then 0.6  # Helps with overall impression
      when 'fix_long_pauses' then 0.4   # Mainly helps with fluency
      else 0.5
      end
    end

    def calculate_context_relevance(improvement_type)
      # Could be enhanced with user-provided context about goals
      context = @user_context[:speech_context] || 'general'

      relevance_map = {
        'interview' => {
          'professional_language' => 1.0,
          'reduce_fillers' => 0.9,
          'enhance_clarity' => 0.8,
          'fix_long_pauses' => 0.7,
          'improve_pace' => 0.6,
          'boost_engagement' => 0.5,
          'increase_fluency' => 0.8
        },
        'presentation' => {
          'boost_engagement' => 1.0,
          'enhance_clarity' => 0.9,
          'improve_pace' => 0.8,
          'reduce_fillers' => 0.7,
          'professional_language' => 0.6,
          'increase_fluency' => 0.8,
          'fix_long_pauses' => 0.5
        },
        'general' => {
          'reduce_fillers' => 0.8,
          'enhance_clarity' => 0.8,
          'improve_pace' => 0.7,
          'boost_engagement' => 0.7,
          'increase_fluency' => 0.7,
          'professional_language' => 0.6,
          'fix_long_pauses' => 0.6
        }
      }

      relevance_map[context]&.[](improvement_type) || 0.7
    end

    def identify_quick_wins(prioritized_areas)
      prioritized_areas.select do |area|
        # Quick wins: high impact, low effort
        area[:priority_score] > 60 && area[:effort_level] <= 2
      end.first(2)
    end

    def generate_practice_plan(top_areas)
      plan = {
        daily_practice: [],
        weekly_goals: [],
        progress_tracking: []
      }

      top_areas.each do |area|
        case area[:type]
        when 'reduce_fillers'
          plan[:daily_practice] << "Practice 2-minute recording focusing on pausing instead of saying 'um' or 'uh'"
          plan[:weekly_goals] << "Reduce filler rate from #{(area[:current_value] * 100).round(1)}% to #{(area[:target_value] * 100).round(1)}%"
          plan[:progress_tracking] << "Count filler words in each practice session"
        when 'improve_pace'
          current_wpm = area[:current_value].round
          target_wpm = area[:target_value].round
          plan[:daily_practice] << "Practice speaking at #{target_wpm} WPM using a metronome or timer"
          plan[:weekly_goals] << "Adjust speaking pace from #{current_wpm} to #{target_wpm} words per minute"
          plan[:progress_tracking] << "Record WPM in 1-minute practice sessions"
        when 'enhance_clarity'
          plan[:daily_practice] << "Practice enunciation exercises and record tongue twisters"
          plan[:weekly_goals] << "Improve clarity score from #{(area[:current_value] * 100).round}% to #{(area[:target_value] * 100).round}%"
          plan[:progress_tracking] << "Ask others to rate your speech clarity on a 1-10 scale"
        end
      end

      plan
    end

    # Impact calculation methods
    def calculate_filler_improvement_impact(current_rate)
      # Reducing filler rate from X to 2% - impact on overall score
      target_rate = 0.02
      improvement = [current_rate - target_rate, 0].max
      # Filler reduction can improve overall score by up to 15 points
      (improvement / 0.10) * 0.15
    end

    def calculate_pace_improvement_impact(current_wpm, target_wpm)
      # Optimal WPM range gives maximum score
      current_pace_score = calculate_wpm_score(current_wpm)
      target_pace_score = calculate_wpm_score(target_wpm)
      improvement = target_pace_score - current_pace_score
      # Pace improvements can affect overall score by up to 10 points
      improvement * 0.10
    end

    def calculate_clarity_improvement_impact(current_clarity)
      target_clarity = 0.85
      improvement = [target_clarity - current_clarity, 0].max
      # Clarity has 35% weight in overall score
      improvement * 0.35
    end

    def calculate_engagement_improvement_impact(current_engagement)
      target_engagement = 0.80
      improvement = [target_engagement - current_engagement, 0].max
      # Engagement has 15% weight in overall score
      improvement * 0.15
    end

    def calculate_fluency_improvement_impact(current_fluency)
      target_fluency = 0.85
      improvement = [target_fluency - current_fluency, 0].max
      # Fluency has 25% weight in overall score
      improvement * 0.25
    end

    def calculate_pause_improvement_impact(long_pause_count)
      # Reducing long pauses improves fluency and clarity
      improvement_ratio = [long_pause_count - 1, 0].max / long_pause_count.to_f
      improvement_ratio * 0.10
    end

    def calculate_professionalism_improvement_impact(unprofessional_count)
      # Professional language mainly affects perception
      improvement_ratio = [unprofessional_count - 1, 0].max / unprofessional_count.to_f
      improvement_ratio * 0.05
    end

    def calculate_wpm_score(wpm)
      case wpm
      when 140..160 then 1.0
      when 120..180 then 0.85
      when 100..120, 180..200 then 0.70
      when 80..100, 200..250 then 0.50
      else 0.30
      end
    end

    def estimate_improvement_time(area)
      base_weeks = DIFFICULTY_LEVELS[area[:type]] || 3

      # Adjust based on severity
      severity_multiplier = case area[:severity]
      when 'high' then 1.5
      when 'medium' then 1.0
      when 'low' then 0.5
      else 1.0
      end

      (base_weeks * severity_multiplier).round
    end

    def generate_actionable_steps(area)
      case area[:type]
      when 'reduce_fillers'
        [
          "Record yourself speaking for 2 minutes daily",
          "Count and track filler words in each recording",
          "Practice pausing for 1-2 seconds instead of saying 'um'",
          "Have a conversation partner signal when you use fillers"
        ]
      when 'improve_pace'
        if area[:current_value] < 140
          [
            "Practice with a metronome set to match target pace",
            "Read aloud for 5 minutes daily at faster pace",
            "Record yourself and gradually increase speed",
            "Focus on maintaining clarity while speeding up"
          ]
        else
          [
            "Practice deliberate pausing between sentences",
            "Emphasize key words by slowing down slightly",
            "Record yourself speaking more slowly",
            "Practice breathing techniques for pace control"
          ]
        end
      when 'enhance_clarity'
        [
          "Practice tongue twisters for 5 minutes daily",
          "Record yourself reading complex passages",
          "Focus on enunciating consonants clearly",
          "Practice speaking with a pen in your mouth (advanced)"
        ]
      when 'boost_engagement'
        [
          "Practice varying your vocal tone and energy",
          "Record yourself telling an exciting story",
          "Add strategic pauses for emphasis",
          "Practice gestures and body language (if video)"
        ]
      when 'increase_fluency'
        [
          "Practice impromptu speaking for 1 minute daily",
          "Record yourself explaining familiar topics",
          "Work on smooth transitions between ideas",
          "Practice speaking without self-corrections"
        ]
      when 'fix_long_pauses'
        [
          "Prepare key talking points before recording",
          "Practice bridging phrases to fill natural gaps",
          "Record yourself with outline notes nearby",
          "Focus on connecting ideas smoothly"
        ]
      when 'professional_language'
        [
          "Replace casual words with professional alternatives",
          "Practice formal speech patterns daily",
          "Record yourself giving a business presentation",
          "Review and correct informal language patterns"
        ]
      else
        ["Practice specific exercises for this area", "Track progress daily", "Record and review regularly"]
      end
    end

    # Issue extraction methods
    def extract_filler_issues
      @issues.where(category: 'filler_words').limit(3).pluck(:text, :start_ms, :tip)
    end

    def extract_pace_issues
      @issues.where(category: 'pace_issues').limit(3).pluck(:text, :start_ms, :tip)
    end

    def extract_clarity_issues
      @issues.where(category: 'clarity_issues').limit(3).pluck(:text, :start_ms, :tip)
    end

    def extract_engagement_issues
      # Engagement issues might be inferred from low energy patterns
      []
    end

    def extract_fluency_issues
      # Fluency issues might include hesitations, restarts
      []
    end

    def extract_pause_issues
      @issues.where("rationale LIKE ?", "%pause%").limit(3).pluck(:text, :start_ms, :tip)
    end

    def extract_professional_issues
      @issues.where(category: 'professional_issues').limit(3).pluck(:text, :start_ms, :tip)
    end

    # Historical analysis methods
    def calculate_historical_average(metric_key)
      values = @historical_sessions.filter_map { |s| s.analysis_data[metric_key] }
      return 0 if values.empty?
      values.sum / values.count.to_f
    end

    def determine_trend(current_value, historical_average)
      return 'stable' if @historical_sessions.count < 2 || historical_average.zero?

      # For metrics where higher is worse (filler_rate), improving means decreasing
      percent_change = ((current_value - historical_average) / historical_average).abs

      if current_value < historical_average * 0.9 # 10% better
        'improving'
      elsif current_value > historical_average * 1.1 # 10% worse
        'worsening'
      else
        'stable'
      end
    end

    # First session recommendation - always prompt user to record again
    def first_session_recommendation
      {
        type: 'record_again_for_baseline',
        actionable_steps: [
          "Record another session so I can analyze your speaking patterns and provide personalized recommendations."
        ],
        priority_score: 100,
        effort_level: 1,
        current_value: nil,
        target_value: nil,
        potential_improvement: 0
      }
    end
  end
end