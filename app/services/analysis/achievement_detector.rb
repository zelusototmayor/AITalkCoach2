module Analysis
  class AchievementDetector
    ACHIEVEMENT_TYPES = {
      streak: {
        thresholds: [ 3, 7, 14, 30, 60, 100 ],
        icon: "🔥",
        title_template: "%{count}-Day Practice Streak",
        description_template: "Practiced for %{count} consecutive days"
      },
      session_milestone: {
        thresholds: [ 5, 10, 25, 50, 100, 250, 500 ],
        icon: "🎯",
        title_template: "%{count} Sessions Completed",
        description_template: "Completed %{count} total practice sessions"
      },
      filler_improvement: {
        thresholds: [ 10, 25, 50, 75 ],
        icon: "💎",
        title_template: "%{count}% Filler Reduction",
        description_template: "Reduced filler words by %{count}% from your baseline"
      },
      clarity_master: {
        thresholds: [ 80, 85, 90, 95 ],
        icon: "✨",
        title_template: "%{count}% Clarity Score",
        description_template: "Achieved %{count}% or higher clarity score"
      },
      pace_control: {
        thresholds: [ 3, 5, 10 ],
        icon: "⚡",
        title_template: "%{count} Sessions in Ideal Pace Range",
        description_template: "Maintained target pace in %{count} consecutive sessions"
      },
      weekly_focus_champion: {
        thresholds: [ 1, 3, 5, 10 ],
        icon: "🏆",
        title_template: "%{count} Weekly Goals Completed",
        description_template: "Successfully completed %{count} weekly focus goals"
      }
    }.freeze

    def initialize(user)
      @user = user
      @sessions = user.sessions.where(completed: true).order(created_at: :desc)
    end

    def detect_achievements
      achievements = []

      # Detect streak achievements
      current_streak = calculate_current_streak
      achievements += generate_achievements_for_metric(:streak, current_streak)

      # Detect session milestone achievements
      total_sessions = @sessions.count
      achievements += generate_achievements_for_metric(:session_milestone, total_sessions)

      # Detect filler improvement achievements
      filler_improvement = calculate_filler_improvement
      achievements += generate_achievements_for_metric(:filler_improvement, filler_improvement) if filler_improvement

      # Detect clarity achievements
      highest_clarity = calculate_highest_clarity
      achievements += generate_achievements_for_metric(:clarity_master, highest_clarity) if highest_clarity

      # Detect pace control achievements
      pace_streak = calculate_pace_control_streak
      achievements += generate_achievements_for_metric(:pace_control, pace_streak)

      # Detect weekly focus completion achievements
      weekly_focus_completions = count_completed_weekly_focuses
      achievements += generate_achievements_for_metric(:weekly_focus_champion, weekly_focus_completions)

      # Sort by recency (most recent first) and take top 5
      achievements.sort_by { |a| -a[:achieved_at].to_i }.first(5)
    end

    def detect_recent_milestones
      # Return achievements from the last 7 days
      all_achievements = detect_achievements
      recent_cutoff = 7.days.ago

      all_achievements.select do |achievement|
        achievement[:achieved_at] && achievement[:achieved_at] > recent_cutoff
      end
    end

    private

    def calculate_current_streak
      return 0 if @sessions.empty?

      streak = 0
      current_date = Date.current

      # Get unique dates with sessions
      session_dates = @sessions.map { |s| s.created_at.to_date }.uniq.sort.reverse

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

    def calculate_filler_improvement
      return nil if @sessions.count < 5

      # Get first 3 sessions as baseline
      baseline_sessions = @sessions.last(3)
      baseline_filler = baseline_sessions.filter_map { |s| s.analysis_data["filler_rate"] }.sum / baseline_sessions.count.to_f

      # Get recent 3 sessions as current
      recent_sessions = @sessions.first(3)
      current_filler = recent_sessions.filter_map { |s| s.analysis_data["filler_rate"] }.sum / recent_sessions.count.to_f

      return nil if baseline_filler.zero?

      # Calculate improvement percentage
      improvement = ((baseline_filler - current_filler) / baseline_filler * 100).round
      improvement > 0 ? improvement : nil
    end

    def calculate_highest_clarity
      clarity_scores = @sessions.filter_map { |s| (s.analysis_data["clarity_score"]&.to_f || 0) * 100 }
      clarity_scores.max&.round
    end

    def calculate_pace_control_streak
      return 0 if @sessions.empty?

      consecutive_count = 0
      # Use user's acceptable WPM range or defaults
      min_wpm = @user.acceptable_wpm_min
      max_wpm = @user.acceptable_wpm_max

      @sessions.each do |session|
        wpm = session.analysis_data["wpm"]&.to_f || 0
        if wpm >= min_wpm && wpm <= max_wpm
          consecutive_count += 1
        else
          break
        end
      end

      consecutive_count
    end

    def count_completed_weekly_focuses
      @user.weekly_focuses.where(status: "completed").count
    end

    def generate_achievements_for_metric(achievement_type, current_value)
      return [] unless current_value && current_value > 0

      config = ACHIEVEMENT_TYPES[achievement_type]
      achievements = []

      config[:thresholds].each do |threshold|
        if current_value >= threshold
          # Check if this is a new achievement (within last 7 days)
          is_recent = check_if_recently_achieved(achievement_type, threshold, current_value)

          achievements << {
            type: achievement_type,
            icon: config[:icon],
            title: config[:title_template] % { count: threshold },
            description: config[:description_template] % { count: threshold },
            threshold: threshold,
            current_value: current_value,
            achieved: true,
            achieved_at: is_recent ? estimate_achievement_date(achievement_type, threshold) : nil
          }
        end
      end

      achievements
    end

    def check_if_recently_achieved(achievement_type, threshold, current_value)
      # Simple heuristic: if we're within 20% of the next threshold, it might be recent
      next_threshold_index = ACHIEVEMENT_TYPES[achievement_type][:thresholds].index { |t| t > current_value }
      return false unless next_threshold_index

      next_threshold = ACHIEVEMENT_TYPES[achievement_type][:thresholds][next_threshold_index]
      current_value >= (threshold * 0.8) && current_value < next_threshold
    end

    def estimate_achievement_date(achievement_type, threshold)
      # Try to estimate when this achievement was reached
      case achievement_type
      when :streak
        # Streak achievements are from the current streak
        Date.current
      when :session_milestone
        # Find the Nth session
        target_session = @sessions.reverse[threshold - 1]
        target_session&.created_at&.to_date || Date.current
      when :weekly_focus_champion
        # Find the Nth completed weekly focus
        completed_focus = @user.weekly_focuses.where(status: "completed").order(week_end: :asc)[threshold - 1]
        completed_focus&.week_end || Date.current
      else
        # For improvement-based achievements, use recent date
        @sessions.first&.created_at&.to_date || Date.current
      end
    end
  end
end
