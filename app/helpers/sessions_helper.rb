module SessionsHelper
  # Map focus type to metric key for highlighting
  def get_metric_key_for_focus(focus_type)
    case focus_type
    when "reduce_fillers" then "filler_rate"
    when "improve_pace" then "pace"
    when "enhance_clarity" then "clarity"
    when "boost_engagement" then "engagement"
    when "increase_fluency" then "fluency"
    when "fix_long_pauses" then "pace_consistency"
    when "improve_sentence_structure" then "clarity"
    else nil
    end
  end

  # Generate personalized narrative for weekly focus
  def generate_weekly_focus_narrative(focus_area, tracking_data)
    focus_type = focus_area[:type]
    current_value = focus_area[:current_value]
    target_value = focus_area[:target_value]
    sessions_completed = tracking_data[:sessions_this_week]
    total_sessions = tracking_data[:target_this_week]

    case focus_type
    when "reduce_fillers"
      current_percent = (current_value * 100).round(1)
      target_percent = (target_value * 100).round(1)

      if sessions_completed == 0
        "Your filler word rate is at #{current_percent}%. Let's reduce it to #{target_percent}% by Sunday. Complete #{total_sessions} focused drills this week."
      elsif sessions_completed < total_sessions / 2
        "You've completed #{sessions_completed}/#{total_sessions} sessions. Your filler rate is at #{current_percent}%. Keep practicing to reach #{target_percent}%!"
      else
        "Great progress! #{sessions_completed}/#{total_sessions} sessions done. Just a few more drills and you'll hit your #{target_percent}% target."
      end

    when "improve_pace"
      current_wpm = current_value.round
      target_wpm = target_value.round

      if sessions_completed == 0
        "Your pace is #{current_wpm} WPM. Let's adjust it to #{target_wpm} WPM through #{total_sessions} practice sessions this week."
      elsif sessions_completed < total_sessions / 2
        "You've practiced #{sessions_completed} times. Keep working on reaching #{target_wpm} WPM from your current #{current_wpm} WPM."
      else
        "Excellent! #{sessions_completed}/#{total_sessions} sessions complete. You're getting closer to your natural pace of #{target_wpm} WPM."
      end

    when "enhance_clarity"
      current_percent = (current_value * 100).round
      target_percent = (target_value * 100).round

      if sessions_completed == 0
        "Your clarity score is #{current_percent}%. Let's boost it to #{target_percent}% by completing #{total_sessions} articulation drills."
      elsif sessions_completed < total_sessions / 2
        "#{sessions_completed}/#{total_sessions} drills completed. Keep improving your clarity from #{current_percent}% to #{target_percent}%."
      else
        "You're #{sessions_completed}/#{total_sessions} sessions in! Keep going to reach your #{target_percent}% clarity target."
      end

    when "boost_engagement", "increase_fluency"
      current_percent = (current_value * 100).round
      target_percent = (target_value * 100).round

      improvement_area = focus_type == "boost_engagement" ? "engagement" : "fluency"

      if sessions_completed == 0
        "Your #{improvement_area} is at #{current_percent}%. Let's increase it to #{target_percent}% through #{total_sessions} focused sessions."
      elsif sessions_completed < total_sessions / 2
        "Progress update: #{sessions_completed}/#{total_sessions} sessions done. Moving from #{current_percent}% to #{target_percent}% #{improvement_area}."
      else
        "Strong work! #{sessions_completed}/#{total_sessions} complete. Almost at your #{target_percent}% #{improvement_area} goal."
      end

    when "improve_sentence_structure"
      issue_count = current_value.to_i
      target_count = target_value.to_i

      if sessions_completed == 0
        "You have #{issue_count} sentence structure issues on average. Let's reduce them to #{target_count} through #{total_sessions} practice sessions."
      elsif sessions_completed < total_sessions / 2
        "#{sessions_completed}/#{total_sessions} sessions done. Keep working on clear sentence structure to reach your target of #{target_count} issues or fewer."
      else
        "Great progress! #{sessions_completed}/#{total_sessions} sessions complete. You're improving your sentence structure consistency."
      end

    else
      "You've completed #{sessions_completed} of #{total_sessions} sessions this week. Keep practicing to reach your target!"
    end
  end
end
