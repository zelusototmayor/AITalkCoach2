class Api::V1::CoachController < Api::V1::BaseController
  # GET /api/v1/coach
  def index
    # Get all completed sessions
    recent_sessions = current_user.sessions
                                  .where(completed: true)
                                  .order(created_at: :asc)
                                  .includes(:issues)

    # Get the most recent completed session
    latest_session = recent_sessions.last

    # Generate recommendations if we have a recent session
    priority_recommendations = nil
    weekly_focus = nil
    daily_plan = nil
    weekly_focus_tracking = nil
    last_session_insight = nil

    if latest_session
      begin
        total_sessions_count = current_user.sessions.where(completed: true).count

        user_context = {
          speech_context: latest_session.speech_context || "general",
          historical_sessions: recent_sessions.to_a,
          total_sessions_count: total_sessions_count
        }

        recommender = Analysis::PriorityRecommender.new(latest_session, user_context)
        priority_recommendations = recommender.generate_priority_recommendations

        # Get or create weekly focus
        weekly_focus = recommender.create_or_update_weekly_focus(current_user)
      rescue => e
        Rails.logger.error "Priority recommendations error: #{e.message}"
      end
    end

    # Generate daily plan based on weekly focus
    if weekly_focus
      plan_generator = Planning::DailyPlanGenerator.new(weekly_focus, current_user)
      daily_plan = plan_generator.generate_plan

      # Calculate weekly focus tracking metrics
      weekly_focus_tracking = calculate_weekly_focus_tracking(weekly_focus)
    end

    # Prepare calendar data
    calendar_data = prepare_calendar_data(recent_sessions)

    # Prepare last session insight
    last_session_insight = prepare_last_session_insight(latest_session, priority_recommendations) if latest_session

    render json: {
      success: true,
      priority_recommendations: priority_recommendations,
      weekly_focus: weekly_focus ? serialize_weekly_focus(weekly_focus) : nil,
      daily_plan: daily_plan,
      weekly_focus_tracking: weekly_focus_tracking,
      latest_session: latest_session ? {
        id: latest_session.id,
        created_at: latest_session.created_at,
        analysis_data: latest_session.analysis_data
      } : nil,
      last_session_insight: last_session_insight,
      calendar_data: calendar_data
    }
  end

  private

  def calculate_weekly_focus_tracking(weekly_focus)
    return nil unless weekly_focus.present?

    today = Date.current

    # Sessions completed today (all completed sessions, not filtered by focus)
    sessions_today = current_user.sessions
                                 .where(completed: true)
                                 .where("DATE(created_at) = ?", today)
                                 .count

    # Sessions completed this week (all completed sessions, not filtered by focus)
    sessions_this_week = current_user.sessions
                                     .where(completed: true)
                                     .where("created_at >= ?", weekly_focus.week_start)
                                     .count

    # Calculate streak
    streak = calculate_focus_streak(weekly_focus)

    # Target sessions per day
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
    sessions = current_user.sessions
                          .where(completed: true)
                          .order(created_at: :desc)

    return 0 if sessions.empty?

    session_dates = sessions.map { |s| s.created_at.to_date }.uniq.sort.reverse
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
    previous_session = current_user.sessions
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

    # Generate narrative
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

    narrative = if strengths.any? && weaknesses.any?
      "You excelled at #{strengths.join(', ')}, but let's work on #{weaknesses.join(', ')}."
    elsif strengths.any?
      "Great session! You showed strong #{strengths.join(', ')}. Keep it up!"
    elsif weaknesses.any?
      "Let's focus on improving #{weaknesses.join(', ')} in your next sessions."
    else
      "Solid session. Keep practicing to see continued improvement."
    end

    # Extract secondary observations
    secondary_observations = if priority_recommendations && priority_recommendations[:secondary_focus]
      priority_recommendations[:secondary_focus].take(2)
    else
      []
    end

    {
      session: session.id,
      narrative: narrative,
      date: session.created_at,
      key_metrics: metrics_with_deltas,
      secondary_observations: secondary_observations
    }
  end

  def prepare_calendar_data(sessions)
    days = []
    year_start = Date.new(Date.current.year, 1, 1)
    year_end = Date.new(Date.current.year, 12, 31)

    (year_start..year_end).each do |date|
      session_on_date = sessions.find { |s| s.created_at.to_date == date }

      days << {
        date: date.iso8601,
        has_session: session_on_date.present?,
        session_count: sessions.count { |s| s.created_at.to_date == date }
      }
    end

    days
  end

  def serialize_weekly_focus(weekly_focus)
    return nil unless weekly_focus

    # Generate descriptive content based on focus type
    title = weekly_focus.focus_type_humanized

    narrative, reasoning = case weekly_focus.focus_type
    when "reduce_fillers"
      starting_pct = (weekly_focus.starting_value * 100).round(1)
      target_pct = (weekly_focus.target_value * 100).round(1)
      [
        "Reduce your filler word rate from #{starting_pct}% to #{target_pct}% this week.",
        "Excessive filler words (um, uh, like) can diminish your credibility and make you sound less confident. Reducing them will make your speech more polished and professional."
      ]
    when "improve_pace"
      starting_wpm = weekly_focus.starting_value.round
      target_wpm = weekly_focus.target_value.round
      [
        "Adjust your speaking pace from #{starting_wpm} WPM to #{target_wpm} WPM.",
        "The ideal speaking pace for presentations is 140-180 words per minute. This range ensures your audience can follow along while maintaining engagement."
      ]
    when "enhance_clarity"
      starting_pct = (weekly_focus.starting_value * 100).round
      target_pct = (weekly_focus.target_value * 100).round
      [
        "Improve your speech clarity from #{starting_pct}% to #{target_pct}%.",
        "Clear speech ensures your message is understood. Focus on enunciation, articulation, and reducing mumbling or slurring."
      ]
    when "boost_engagement"
      starting_pct = (weekly_focus.starting_value * 100).round
      target_pct = (weekly_focus.target_value * 100).round
      [
        "Increase your engagement score from #{starting_pct}% to #{target_pct}%.",
        "Engaging speech uses varied intonation, emphasis, and energy to keep listeners interested and attentive."
      ]
    when "increase_fluency"
      starting_pct = (weekly_focus.starting_value * 100).round
      target_pct = (weekly_focus.target_value * 100).round
      [
        "Boost your fluency from #{starting_pct}% to #{target_pct}%.",
        "Fluent speech flows naturally without unnecessary hesitations or restarts. Practice will help you speak more smoothly and confidently."
      ]
    when "fix_long_pauses"
      [
        "Reduce excessive pauses in your speech.",
        "While some pauses are natural and helpful, long or frequent pauses can make you seem uncertain. Work on maintaining steady flow while still using strategic pauses for emphasis."
      ]
    when "professional_language"
      [
        "Use more professional and precise language.",
        "Professional language enhances credibility. Focus on using specific terminology, avoiding casual expressions, and structuring your thoughts clearly."
      ]
    else
      [
        "Improve your #{weekly_focus.focus_type_humanized.downcase}.",
        "Work on this aspect of your communication to become a more effective speaker."
      ]
    end

    {
      id: weekly_focus.id,
      title: title,
      narrative: narrative,
      reasoning: reasoning,
      time_estimate: "6-8 min/day",
      focus_type: weekly_focus.focus_type,
      target_value: weekly_focus.target_value,
      starting_value: weekly_focus.starting_value,
      week_start: weekly_focus.week_start,
      week_end: weekly_focus.week_end,
      target_sessions_per_week: weekly_focus.target_sessions_per_week,
      status: weekly_focus.status,
      completion_percentage: weekly_focus.completion_percentage,
      days_remaining: weekly_focus.days_remaining
    }
  end
end
