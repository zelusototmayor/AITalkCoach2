class Api::V1::ProgressController < Api::V1::BaseController
  # GET /api/v1/progress
  def index
    time_range = params[:range] || '7'

    # Get all completed sessions
    sessions = current_user.sessions
                          .where(completed: true)
                          .order(created_at: :asc)
                          .includes(:issues)

    # Get weekly focus
    weekly_focus = WeeklyFocus.current_for_user(current_user)

    # Prepare chart data
    chart_data = prepare_chart_data(sessions, time_range)

    # Prepare skill snapshot
    skill_snapshot = prepare_skill_snapshot(sessions)

    # Prepare calendar data
    calendar_data = prepare_calendar_data(sessions)

    # Detect achievements
    begin
      achievement_detector = Analysis::AchievementDetector.new(current_user)
      achievements = achievement_detector.detect_achievements
      recent_milestones = achievement_detector.detect_recent_milestones
    rescue => e
      Rails.logger.error "Achievement detection error: #{e.message}"
      achievements = []
      recent_milestones = []
    end

    render json: {
      success: true,
      chart_data: chart_data,
      skill_snapshot: skill_snapshot,
      calendar_data: calendar_data,
      achievements: achievements,
      recent_milestones: recent_milestones,
      weekly_focus: weekly_focus,
      current_values: extract_current_values(sessions),
      average_values: extract_average_values(sessions, time_range),
      best_values: extract_best_values(sessions),
      trends: extract_trends(sessions),
      deltas: extract_deltas(sessions)
    }
  end

  private

  def prepare_chart_data(sessions, time_range)
    return {} if sessions.empty?

    # Filter sessions based on time range
    chart_sessions = case time_range
    when "7"
      sessions.last(7)
    when "10"
      # Last 10 days
      sessions.where('created_at >= ?', 10.days.ago)
    when "10_sessions"
      # Last 10 sessions
      sessions.last(10)
    when "30"
      sessions.last(30)
    when "lifetime"
      sessions
    when /^custom:(.+):(.+)$/
      # Custom date range: custom:YYYY-MM-DD:YYYY-MM-DD
      start_date = Date.parse($1) rescue 7.days.ago.to_date
      end_date = Date.parse($2) rescue Date.today
      sessions.where('created_at >= ? AND created_at <= ?', start_date.beginning_of_day, end_date.end_of_day)
    else
      sessions.last(7)
    end

    labels = if chart_sessions.count > 30
      chart_sessions.map.with_index { |s, i|
        (i + 1) % 5 == 0 || i == 0 || i == chart_sessions.count - 1 ? "#{i + 1}" : ""
      }
    else
      chart_sessions.map.with_index { |s, i| "Session #{i + 1}" }
    end

    {
      labels: labels,
      overall_score_data: chart_sessions.map { |s| (s.analysis_data["overall_score"].to_f * 100).round },
      filler_data: chart_sessions.map { |s| (s.analysis_data["filler_rate"].to_f * 100).round(1) },
      pace_data: chart_sessions.map { |s| s.analysis_data["wpm"].to_f.round },
      clarity_data: chart_sessions.map { |s| (s.analysis_data["clarity_score"].to_f * 100).round },
      pace_consistency_data: chart_sessions.map { |s| (s.analysis_data["pace_consistency"].to_f * 100).round },
      fluency_data: chart_sessions.map { |s| (s.analysis_data["fluency_score"].to_f * 100).round },
      engagement_data: chart_sessions.map { |s| (s.analysis_data["engagement_score"].to_f * 100).round },
      time_range: time_range,
      session_count: chart_sessions.count
    }
  end

  def prepare_skill_snapshot(sessions)
    return {} if sessions.empty?

    recent_count = [5, sessions.count].min
    recent_sessions = sessions.last(recent_count)
    baseline_sessions = sessions

    # Calculate averages
    recent_overall = calculate_average(recent_sessions, "overall_score")
    baseline_overall = calculate_average(baseline_sessions, "overall_score")

    {
      overall_score: {
        score: (recent_overall * 100).round,
        delta: ((recent_overall - baseline_overall) * 100).round
      },
      clarity: {
        score: (calculate_average(recent_sessions, "clarity_score") * 100).round,
        delta: ((calculate_average(recent_sessions, "clarity_score") -
                calculate_average(baseline_sessions, "clarity_score")) * 100).round
      },
      filler_rate: {
        score: (calculate_average(recent_sessions, "filler_rate") * 100).round(1),
        delta: ((calculate_average(recent_sessions, "filler_rate") -
                calculate_average(baseline_sessions, "filler_rate")) * 100).round(1)
      },
      pace: {
        score: calculate_average(recent_sessions, "wpm").round,
        delta: (calculate_average(recent_sessions, "wpm") -
               calculate_average(baseline_sessions, "wpm")).round
      }
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

  def calculate_average(sessions, metric_key)
    values = sessions.filter_map { |s| s.analysis_data[metric_key] }
    return 0 if values.empty?
    values.sum / values.count.to_f
  end

  def extract_current_values(sessions)
    return {} if sessions.empty?
    latest = sessions.last
    return {} unless latest&.analysis_data

    {
      overall_score: latest.analysis_data["overall_score"],
      filler_rate: latest.analysis_data["filler_rate"],
      wpm: latest.analysis_data["wpm"],
      clarity_score: latest.analysis_data["clarity_score"],
      fluency_score: latest.analysis_data["fluency_score"],
      engagement_score: latest.analysis_data["engagement_score"],
      pace_consistency: latest.analysis_data["pace_consistency"]
    }
  end

  def extract_average_values(sessions, time_range)
    return {} if sessions.empty?

    # Filter sessions based on time range (matching chart data logic)
    filtered_sessions = case time_range
    when "10_sessions"
      sessions.last(10)
    when "7"
      sessions.last(7)
    when "10"
      sessions.where('created_at >= ?', 10.days.ago)
    else
      sessions.last(10) # Default to last 10 sessions
    end

    {
      overall_score: calculate_average(filtered_sessions, "overall_score"),
      filler_rate: calculate_average(filtered_sessions, "filler_rate"),
      wpm: calculate_average(filtered_sessions, "wpm"),
      clarity_score: calculate_average(filtered_sessions, "clarity_score"),
      fluency_score: calculate_average(filtered_sessions, "fluency_score"),
      engagement_score: calculate_average(filtered_sessions, "engagement_score"),
      pace_consistency: calculate_average(filtered_sessions, "pace_consistency")
    }
  end

  def extract_best_values(sessions)
    return {} if sessions.empty?

    {
      overall_score: sessions.map { |s| s.analysis_data["overall_score"].to_f }.max,
      filler_rate: sessions.map { |s| s.analysis_data["filler_rate"].to_f }.min,
      wpm: sessions.map { |s| s.analysis_data["wpm"].to_f }.max,
      clarity_score: sessions.map { |s| s.analysis_data["clarity_score"].to_f }.max,
      fluency_score: sessions.map { |s| s.analysis_data["fluency_score"].to_f }.max,
      engagement_score: sessions.map { |s| s.analysis_data["engagement_score"].to_f }.max,
      pace_consistency: sessions.map { |s| s.analysis_data["pace_consistency"].to_f }.max
    }
  end

  def extract_trends(sessions)
    return {} if sessions.length < 2

    recent_5 = sessions.last(5)
    previous_5 = sessions.length > 5 ? sessions[-10..-6] || [] : []

    return {} if recent_5.empty?

    metrics = [:overall_score, :filler_rate, :wpm, :clarity_score, :fluency_score, :engagement_score, :pace_consistency]
    trends = {}

    metrics.each do |metric|
      recent_avg = calculate_average(recent_5, metric.to_s)

      if previous_5.any?
        prev_avg = calculate_average(previous_5, metric.to_s)
        trends[metric] = recent_avg > prev_avg ? 'up' : (recent_avg < prev_avg ? 'down' : 'neutral')
      else
        trends[metric] = 'neutral'
      end
    end

    trends
  end

  def extract_deltas(sessions)
    return {} if sessions.length < 2

    latest = sessions.last
    previous = sessions[-2]

    return {} unless latest&.analysis_data && previous&.analysis_data

    {
      overall_score: (latest.analysis_data["overall_score"].to_f - previous.analysis_data["overall_score"].to_f).round(2),
      filler_rate: (latest.analysis_data["filler_rate"].to_f - previous.analysis_data["filler_rate"].to_f).round(2),
      wpm: (latest.analysis_data["wpm"].to_f - previous.analysis_data["wpm"].to_f).round(1),
      clarity_score: (latest.analysis_data["clarity_score"].to_f - previous.analysis_data["clarity_score"].to_f).round(2)
    }
  end
end