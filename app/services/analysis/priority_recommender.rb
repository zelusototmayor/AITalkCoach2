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
      "reduce_fillers" => 2,      # Moderate - requires practice and awareness
      "improve_pace" => 3,        # Hard - requires timing and rhythm practice
      "enhance_clarity" => 4,     # Very hard - requires articulation work
      "boost_engagement" => 3,    # Hard - requires energy and variety
      "increase_fluency" => 4,    # Very hard - requires extensive practice
      "fix_long_pauses" => 2,     # Moderate - awareness and preparation help
      "professional_language" => 1 # Easy - vocabulary substitution
    }.freeze

    def initialize(session, user_context = {})
      @session = session
      @user_context = user_context
      @historical_sessions = user_context[:historical_sessions] || [ session ]
      @total_sessions_count = user_context[:total_sessions_count] || @historical_sessions.count
      @analysis_data = session.analysis_data
      @issues = session.issues.includes(:session)
    end

    def generate_priority_recommendations
      return [] unless @analysis_data.present?

      # Special handling for first session - always prompt to record again for baseline
      # Use total_sessions_count (all user sessions) not historical_sessions (which may be filtered)
      if @total_sessions_count == 1
        return {
          focus_this_week: [ first_session_recommendation ],
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

    # Create or update weekly focus from recommendations
    def create_or_update_weekly_focus(user)
      # Don't create for first session - need baseline
      # Use total_sessions_count to check if this is truly the user's first session
      return nil if @total_sessions_count == 1

      # Check if user already has an active weekly focus for current week
      existing_focus = WeeklyFocus.current_for_user(user)

      # If exists and is current, return it
      return existing_focus if existing_focus&.is_current?

      # Mark any previous week's focus as completed or missed
      if existing_focus && !existing_focus.is_current?
        completion_rate = existing_focus.completion_percentage
        if completion_rate >= 70
          existing_focus.mark_completed!
        else
          existing_focus.mark_missed!
        end
      end

      # Generate new recommendations and create weekly focus
      recommendations = generate_priority_recommendations

      # Create new weekly focus from top recommendation
      WeeklyFocus.create_from_recommendation(user, recommendations)
    end

    private

    def identify_improvement_areas
      areas = []

      # Use rolling average of last 5 sessions (or all if < 5, minimum 2)
      # This prevents one outlier session from drastically changing the weekly focus
      recent_sessions = @historical_sessions.last([ 5, @historical_sessions.count ].min)

      # Analyze each metric using rolling average for stability
      current_metrics = {
        filler_rate: calculate_rolling_average(recent_sessions, "filler_rate"),
        clarity_score: calculate_rolling_average(recent_sessions, "clarity_score"),
        fluency_score: calculate_rolling_average(recent_sessions, "fluency_score"),
        engagement_score: calculate_rolling_average(recent_sessions, "engagement_score"),
        pace_consistency: calculate_rolling_average(recent_sessions, "pace_consistency"),
        overall_score: calculate_rolling_average(recent_sessions, "overall_score"),
        wpm: calculate_rolling_average(recent_sessions, "wpm")
      }

      # Get current session values for contextual messaging
      session_metrics = {
        filler_rate: @analysis_data["filler_rate"],
        clarity_score: @analysis_data["clarity_score"],
        fluency_score: @analysis_data["fluency_score"],
        engagement_score: @analysis_data["engagement_score"],
        pace_consistency: @analysis_data["pace_consistency"],
        overall_score: @analysis_data["overall_score"],
        wpm: @analysis_data["wpm"]
      }

      # Filler words analysis
      if current_metrics[:filler_rate] > 0.03 # More than 3%
        avg_filler = calculate_historical_average("filler_rate")
        filler_trend = determine_trend(current_metrics[:filler_rate], avg_filler)
        severity = current_metrics[:filler_rate] > 0.07 ? "high" : "medium"

        area = {
          type: "reduce_fillers",
          current_value: current_metrics[:filler_rate],
          current_session_value: session_metrics[:filler_rate],
          target_value: 0.02,
          historical_average: avg_filler,
          trend: filler_trend,
          sessions_analyzed: @historical_sessions.count,
          potential_improvement: calculate_filler_improvement_impact(current_metrics[:filler_rate]),
          severity: severity,
          specific_issues: extract_filler_issues
        }

        # Add contextual message based on session achievement
        area[:contextual_message] = generate_contextual_message(area)
        areas << area
      end

      # Pace analysis (optimal range: 130-150 WPM, acceptable: 110-170 WPM)
      wpm = current_metrics[:wpm]
      if wpm < 110 || wpm > 170
        # Only recommend improvement if outside acceptable range
        target_wpm = wpm < 110 ? 135 : 145

        area = {
          type: "improve_pace",
          current_value: wpm,
          current_session_value: session_metrics[:wpm],
          target_value: target_wpm,
          potential_improvement: calculate_pace_improvement_impact(wpm, target_wpm),
          severity: wpm < 90 || wpm > 190 ? "high" : "medium",
          specific_issues: extract_pace_issues
        }

        # Add contextual message based on session achievement
        area[:contextual_message] = generate_contextual_message(area)
        areas << area
      end

      # Clarity analysis
      if current_metrics[:clarity_score] < 0.75
        area = {
          type: "enhance_clarity",
          current_value: current_metrics[:clarity_score],
          current_session_value: session_metrics[:clarity_score],
          target_value: 0.85,
          potential_improvement: calculate_clarity_improvement_impact(current_metrics[:clarity_score]),
          severity: current_metrics[:clarity_score] < 0.60 ? "high" : "medium",
          specific_issues: extract_clarity_issues
        }

        area[:contextual_message] = generate_contextual_message(area)
        areas << area
      end

      # Engagement analysis
      if current_metrics[:engagement_score] < 0.70
        area = {
          type: "boost_engagement",
          current_value: current_metrics[:engagement_score],
          current_session_value: session_metrics[:engagement_score],
          target_value: 0.80,
          potential_improvement: calculate_engagement_improvement_impact(current_metrics[:engagement_score]),
          severity: current_metrics[:engagement_score] < 0.50 ? "high" : "medium",
          specific_issues: extract_engagement_issues
        }

        area[:contextual_message] = generate_contextual_message(area)
        areas << area
      end

      # Fluency analysis
      if current_metrics[:fluency_score] < 0.75
        area = {
          type: "increase_fluency",
          current_value: current_metrics[:fluency_score],
          current_session_value: session_metrics[:fluency_score],
          target_value: 0.85,
          potential_improvement: calculate_fluency_improvement_impact(current_metrics[:fluency_score]),
          severity: current_metrics[:fluency_score] < 0.60 ? "high" : "medium",
          specific_issues: extract_fluency_issues
        }

        area[:contextual_message] = generate_contextual_message(area)
        areas << area
      end

      # Long pause analysis
      long_pause_count = @analysis_data["long_pause_count"] || 0
      if long_pause_count > 2
        areas << {
          type: "fix_long_pauses",
          current_value: long_pause_count,
          target_value: 1,
          potential_improvement: calculate_pause_improvement_impact(long_pause_count),
          severity: long_pause_count > 5 ? "high" : "medium",
          specific_issues: extract_pause_issues
        }
      end

      # Professional language analysis
      unprofessional_issues = @issues.where(category: "professional_issues").count
      if unprofessional_issues > 3
        areas << {
          type: "professional_language",
          current_value: unprofessional_issues,
          target_value: 1,
          potential_improvement: calculate_professionalism_improvement_impact(unprofessional_issues),
          severity: unprofessional_issues > 6 ? "high" : "low",
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
      when "reduce_fillers" then 0.8    # Helps with fluency, clarity, professionalism
      when "enhance_clarity" then 0.9   # Helps with everything
      when "improve_pace" then 0.7      # Helps with engagement and clarity
      when "increase_fluency" then 0.6  # Helps with clarity and engagement
      when "professional_language" then 0.5 # Mainly helps with professionalism
      when "boost_engagement" then 0.6  # Helps with overall impression
      when "fix_long_pauses" then 0.4   # Mainly helps with fluency
      else 0.5
      end
    end

    def calculate_context_relevance(improvement_type)
      # Could be enhanced with user-provided context about goals
      context = @user_context[:speech_context] || "general"

      relevance_map = {
        "interview" => {
          "professional_language" => 1.0,
          "reduce_fillers" => 0.9,
          "enhance_clarity" => 0.8,
          "fix_long_pauses" => 0.7,
          "improve_pace" => 0.6,
          "boost_engagement" => 0.5,
          "increase_fluency" => 0.8
        },
        "presentation" => {
          "boost_engagement" => 1.0,
          "enhance_clarity" => 0.9,
          "improve_pace" => 0.8,
          "reduce_fillers" => 0.7,
          "professional_language" => 0.6,
          "increase_fluency" => 0.8,
          "fix_long_pauses" => 0.5
        },
        "general" => {
          "reduce_fillers" => 0.8,
          "enhance_clarity" => 0.8,
          "improve_pace" => 0.7,
          "boost_engagement" => 0.7,
          "increase_fluency" => 0.7,
          "professional_language" => 0.6,
          "fix_long_pauses" => 0.6
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
        when "reduce_fillers"
          plan[:daily_practice] << "Practice 2-minute recording focusing on pausing instead of saying 'um' or 'uh'"
          plan[:weekly_goals] << "Reduce filler rate from #{(area[:current_value] * 100).round(1)}% to #{(area[:target_value] * 100).round(1)}%"
          plan[:progress_tracking] << "Count filler words in each practice session"
        when "improve_pace"
          current_wpm = area[:current_value].round
          target_wpm = area[:target_value].round
          plan[:daily_practice] << "Practice speaking at #{target_wpm} WPM using a metronome or timer"
          plan[:weekly_goals] << "Adjust speaking pace from #{current_wpm} to #{target_wpm} words per minute"
          plan[:progress_tracking] << "Record WPM in 1-minute practice sessions"
        when "enhance_clarity"
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
      improvement = [ current_rate - target_rate, 0 ].max
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
      improvement = [ target_clarity - current_clarity, 0 ].max
      # Clarity has 35% weight in overall score
      improvement * 0.35
    end

    def calculate_engagement_improvement_impact(current_engagement)
      target_engagement = 0.80
      improvement = [ target_engagement - current_engagement, 0 ].max
      # Engagement has 15% weight in overall score
      improvement * 0.15
    end

    def calculate_fluency_improvement_impact(current_fluency)
      target_fluency = 0.85
      improvement = [ target_fluency - current_fluency, 0 ].max
      # Fluency has 25% weight in overall score
      improvement * 0.25
    end

    def calculate_pause_improvement_impact(long_pause_count)
      # Reducing long pauses improves fluency and clarity
      improvement_ratio = [ long_pause_count - 1, 0 ].max / long_pause_count.to_f
      improvement_ratio * 0.10
    end

    def calculate_professionalism_improvement_impact(unprofessional_count)
      # Professional language mainly affects perception
      improvement_ratio = [ unprofessional_count - 1, 0 ].max / unprofessional_count.to_f
      improvement_ratio * 0.05
    end

    def calculate_wpm_score(wpm)
      case wpm
      when 130..150 then 1.0
      when 110..170 then 0.85
      when 90..110, 170..190 then 0.70
      when 70..90, 190..240 then 0.50
      else 0.30
      end
    end

    def estimate_improvement_time(area)
      base_weeks = DIFFICULTY_LEVELS[area[:type]] || 3

      # Adjust based on severity
      severity_multiplier = case area[:severity]
      when "high" then 1.5
      when "medium" then 1.0
      when "low" then 0.5
      else 1.0
      end

      (base_weeks * severity_multiplier).round
    end

    def generate_actionable_steps(area)
      # Generate personalized steps with specific data points
      case area[:type]
      when "reduce_fillers"
        current_percent = (area[:current_value] * 100).round(1)
        target_percent = (area[:target_value] * 100).round(1)

        # Get most common filler words from specific issues
        common_fillers = area[:specific_issues]&.map { |issue| issue[0] }&.take(2) || ["um", "uh"]
        filler_examples = common_fillers.join(" and ")

        [
          "In your recent sessions, you averaged #{current_percent}% filler words—let's reduce that to #{target_percent}%.",
          "Your most common fillers are '#{filler_examples}'. Practice pausing for 1-2 seconds instead.",
          "Record yourself for 2 minutes daily focusing on eliminating these specific words.",
          "Try the 'pause drill': speak on a topic and pause deliberately where you'd normally say #{filler_examples}."
        ]
      when "improve_pace"
        current_wpm = area[:current_value].round
        target_wpm = area[:target_value].round

        if current_wpm < 110
          [
            "Your current pace is #{current_wpm} WPM. Let's increase it to #{target_wpm} WPM (optimal range: 130-150 WPM).",
            "Practice with a metronome set to #{target_wpm} beats per minute (1 word per beat).",
            "Read aloud for 5 minutes daily, gradually increasing speed while maintaining clarity.",
            "Record yourself and check your WPM after each session to track improvement."
          ]
        else
          [
            "Your pace is #{current_wpm} WPM—too fast. Let's bring it down to #{target_wpm} WPM (optimal range: 130-150 WPM).",
            "Practice deliberate pausing for 2-3 seconds between key points.",
            "Focus on emphasizing important words by slowing down slightly on them.",
            "Practice breathing techniques: inhale for 4 counts, exhale slowly while speaking."
          ]
        end
      when "enhance_clarity"
        current_percent = (area[:current_value] * 100).round
        target_percent = (area[:target_value] * 100).round

        [
          "Your clarity score is #{current_percent}%—let's boost it to #{target_percent}% with articulation practice.",
          "Practice tongue twisters for 5 minutes daily: 'She sells seashells' and 'Red leather, yellow leather'.",
          "Record yourself reading complex passages and listen for mumbled words.",
          "Focus on enunciating consonants clearly, especially at the ends of words."
        ]
      when "boost_engagement"
        current_percent = (area[:current_value] * 100).round
        target_percent = (area[:target_value] * 100).round

        [
          "Your engagement level is #{current_percent}%—aim for #{target_percent}% by adding vocal variety.",
          "Practice varying your pitch: go higher for questions, lower for important points.",
          "Record yourself telling an exciting story, exaggerating your energy level.",
          "Add strategic pauses (2-3 seconds) before key points to build anticipation."
        ]
      when "increase_fluency"
        current_percent = (area[:current_value] * 100).round
        target_percent = (area[:target_value] * 100).round

        [
          "Your fluency is at #{current_percent}%—let's improve it to #{target_percent}% with consistent practice.",
          "Practice impromptu speaking: set a timer for 1 minute and speak on a random topic.",
          "Work on smooth transitions between ideas using phrases like 'building on that' or 'similarly'.",
          "Record yourself explaining familiar topics without notes—focus on continuous flow."
        ]
      when "fix_long_pauses"
        pause_count = area[:current_value].to_i

        [
          "You had #{pause_count} long pauses in your last session—let's reduce that to 1-2 max.",
          "Prepare 3-5 key talking points before recording to avoid searching for ideas.",
          "Practice bridging phrases: 'What I mean by that is...', 'In other words...'",
          "Keep brief notes nearby during practice to glance at without losing momentum."
        ]
      when "professional_language"
        issue_count = area[:current_value].to_i

        [
          "You used #{issue_count} casual phrases that could be more professional.",
          "Replace casual words: 'stuff' → 'matters', 'things' → 'items', 'like' → 'such as'.",
          "Practice formal speech patterns: avoid contractions, use complete sentences.",
          "Record yourself giving a mock business presentation and review for informal language."
        ]
      else
        [ "Practice specific exercises for this area", "Track progress daily", "Record and review regularly" ]
      end
    end

    # Issue extraction methods
    def extract_filler_issues
      @issues.where(category: "filler_words").limit(3).pluck(:text, :start_ms, :tip)
    end

    def extract_pace_issues
      @issues.where(category: "pace_issues").limit(3).pluck(:text, :start_ms, :tip)
    end

    def extract_clarity_issues
      @issues.where(category: "clarity_issues").limit(3).pluck(:text, :start_ms, :tip)
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
      @issues.where(category: "professional_issues").limit(3).pluck(:text, :start_ms, :tip)
    end

    # Historical analysis methods
    def calculate_historical_average(metric_key)
      values = @historical_sessions.filter_map { |s| s.analysis_data[metric_key] }
      return 0 if values.empty?
      values.sum / values.count.to_f
    end

    def calculate_rolling_average(sessions, metric_key)
      values = sessions.filter_map { |s| s.analysis_data[metric_key] }
      return 0 if values.empty?
      values.sum / values.count.to_f
    end

    def determine_trend(current_value, historical_average)
      return "stable" if @historical_sessions.count < 2 || historical_average.zero?

      # For metrics where higher is worse (filler_rate), improving means decreasing
      percent_change = ((current_value - historical_average) / historical_average).abs

      if current_value < historical_average * 0.9 # 10% better
        "improving"
      elsif current_value > historical_average * 1.1 # 10% worse
        "worsening"
      else
        "stable"
      end
    end

    # Generate contextual message based on current session achievement
    def generate_contextual_message(area)
      current_session = area[:current_session_value]
      rolling_avg = area[:current_value]
      target = area[:target_value]

      return nil unless current_session && rolling_avg && target

      # Check if current session achieved target
      achieved = session_achieved_target?(area)
      close_to_target = within_threshold_of_target?(area, 0.10) # Within 10%

      case area[:type]
      when "improve_pace"
        if achieved
          {
            badge: "GREAT SESSION 🎉",
            title: "Amazing pace this session!",
            body: "You hit #{current_session.round} WPM this session - #{current_session < 110 ? 'great improvement' : 'excellent control'}! Your 5-session average is #{rolling_avg.round} WPM. Keep practicing to make #{target.round}+ WPM your consistent baseline."
          }
        elsif close_to_target
          {
            badge: "ALMOST THERE 💪",
            title: "You're getting close!",
            body: "This session: #{current_session.round} WPM. Your 5-session average (#{rolling_avg.round} WPM) shows steady progress toward #{target.round} WPM."
          }
        else
          {
            badge: "KEEP GOING 💪",
            title: "Improve Speaking Pace",
            body: "Your average pace is #{rolling_avg.round} WPM. Let's #{rolling_avg < 110 ? 'increase' : 'adjust'} it to #{target.round} WPM gradually through consistent practice."
          }
        end

      when "reduce_fillers"
        if achieved
          {
            badge: "GREAT SESSION 🎉",
            title: "Clean speech this session!",
            body: "Only #{(current_session * 100).round(1)}% filler words - excellent! Your 5-session average is #{(rolling_avg * 100).round(1)}%. Keep it up to reach #{(target * 100).round(1)}% consistently."
          }
        elsif close_to_target
          {
            badge: "ALMOST THERE 💪",
            title: "You're getting close!",
            body: "This session: #{(current_session * 100).round(1)}% fillers. Your 5-session average (#{(rolling_avg * 100).round(1)}%) shows progress toward #{(target * 100).round(1)}%."
          }
        else
          {
            badge: "KEEP GOING 💪",
            title: "Reduce Filler Words",
            body: "Your average filler rate is #{(rolling_avg * 100).round(1)}%. Let's reduce it to #{(target * 100).round(1)}% through mindful pausing."
          }
        end

      when "enhance_clarity"
        if achieved
          {
            badge: "GREAT SESSION 🎉",
            title: "Crystal clear this session!",
            body: "#{(current_session * 100).round}% clarity score - excellent articulation! Your 5-session average is #{(rolling_avg * 100).round}%. Keep practicing to maintain #{(target * 100).round}%+ consistently."
          }
        elsif close_to_target
          {
            badge: "ALMOST THERE 💪",
            title: "You're getting close!",
            body: "This session: #{(current_session * 100).round}% clarity. Your 5-session average (#{(rolling_avg * 100).round}%) shows improvement toward #{(target * 100).round}%."
          }
        else
          {
            badge: "KEEP GOING 💪",
            title: "Enhance Clarity",
            body: "Your average clarity is #{(rolling_avg * 100).round}%. Let's boost it to #{(target * 100).round}% with articulation practice."
          }
        end

      when "boost_engagement"
        if achieved
          {
            badge: "GREAT SESSION 🎉",
            title: "Energetic delivery this session!",
            body: "#{(current_session * 100).round}% engagement score - great vocal variety! Your 5-session average is #{(rolling_avg * 100).round}%. Keep it up to maintain #{(target * 100).round}%+ energy."
          }
        elsif close_to_target
          {
            badge: "ALMOST THERE 💪",
            title: "You're getting close!",
            body: "This session: #{(current_session * 100).round}% engagement. Your 5-session average (#{(rolling_avg * 100).round}%) shows progress toward #{(target * 100).round}%."
          }
        else
          {
            badge: "KEEP GOING 💪",
            title: "Boost Engagement",
            body: "Your average engagement is #{(rolling_avg * 100).round}%. Let's increase it to #{(target * 100).round}% with more vocal variety."
          }
        end

      when "increase_fluency"
        if achieved
          {
            badge: "GREAT SESSION 🎉",
            title: "Smooth delivery this session!",
            body: "#{(current_session * 100).round}% fluency score - very smooth! Your 5-session average is #{(rolling_avg * 100).round}%. Keep practicing to maintain #{(target * 100).round}%+ fluency."
          }
        elsif close_to_target
          {
            badge: "ALMOST THERE 💪",
            title: "You're getting close!",
            body: "This session: #{(current_session * 100).round}% fluency. Your 5-session average (#{(rolling_avg * 100).round}%) shows improvement toward #{(target * 100).round}%."
          }
        else
          {
            badge: "KEEP GOING 💪",
            title: "Increase Fluency",
            body: "Your average fluency is #{(rolling_avg * 100).round}%. Let's improve it to #{(target * 100).round}% with consistent practice."
          }
        end

      else
        # Default message for other types
        {
          badge: "KEEP GOING 💪",
          title: area[:type].titleize,
          body: "Keep practicing to improve this area."
        }
      end
    end

    # Check if current session achieved the target
    def session_achieved_target?(area)
      current_session = area[:current_session_value]
      target = area[:target_value]

      return false unless current_session && target

      case area[:type]
      when "improve_pace"
        # Achieved if within optimal range (110-170 WPM)
        current_session.round.between?(110, 170)
      when "reduce_fillers"
        # Achieved if at or below target
        current_session <= target
      when "enhance_clarity", "boost_engagement", "increase_fluency"
        # Achieved if at or above target
        current_session >= target
      else
        false
      end
    end

    # Check if current session is within threshold of target
    def within_threshold_of_target?(area, threshold)
      current_session = area[:current_session_value]
      target = area[:target_value]

      return false unless current_session && target

      case area[:type]
      when "improve_pace"
        # Within 10% of target range
        (current_session - target).abs <= (target * threshold)
      when "reduce_fillers"
        # Within threshold (e.g., 10%) for rates
        (current_session - target).abs <= threshold
      when "enhance_clarity", "boost_engagement", "increase_fluency"
        # Within threshold (e.g., 10%) for scores
        (current_session - target).abs <= threshold
      else
        false
      end
    end

    # First session recommendation - always prompt user to record again
    def first_session_recommendation
      {
        type: "record_again_for_baseline",
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

    # Check if a recommendation type matches a weekly focus improvement type
    def self.matches_focus_type?(recommendation_type, weekly_focus_type)
      return false if recommendation_type.nil? || weekly_focus_type.nil?
      normalize_type(recommendation_type) == normalize_type(weekly_focus_type)
    end

    # Normalize type strings for comparison
    def self.normalize_type(type)
      type.to_s.downcase.gsub(/[^a-z_]/, "_")
    end
  end
end
