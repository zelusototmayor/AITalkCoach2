module Planning
  class DailyPlanGenerator
    # Drill templates for different focus types
    DRILL_TEMPLATES = {
      "reduce_fillers" => [
        {
          title: "60s Filler Pause Drill",
          description: "Speak about the prompt topic for 60 seconds. Whenever you feel the urge to say 'um', 'uh', or 'like', PAUSE for 1-2 seconds instead. Focus on replacing fillers with intentional silence.",
          duration_seconds: 60,
          drill_type: "pause_practice",
          icon: "🎤",
          target_reps: 2
        },
        {
          title: "Guided 2-min Practice",
          description: "Record yourself for 2 minutes. In the first minute, speak naturally. In the second minute, actively monitor for filler words and pause whenever you catch yourself about to use one. Compare your filler usage between the two halves.",
          duration_seconds: 120,
          drill_type: "guided_practice",
          icon: "⭐",
          target_reps: 1
        },
        {
          title: "Filler Awareness Exercise",
          description: "Record yourself for 90 seconds. Listen back and count every filler word ('um', 'uh', 'like', 'you know'). Write down your count. Record again with the goal of reducing fillers by at least 50%.",
          duration_seconds: 90,
          drill_type: "awareness",
          icon: "🎯",
          target_reps: 1
        }
      ],
      "improve_pace" => [
        {
          title: "60s Pace Drill @150 WPM",
          description: "Speak about the prompt topic for 60 seconds. Aim for 140-160 words per minute (roughly 2.5 words per second). Count to yourself: '1-2-3' between sentences to maintain steady pacing. Focus on consistency.",
          duration_seconds: 60,
          drill_type: "metronome_practice",
          icon: "⏱️",
          target_reps: 2
        },
        {
          title: "Pace Variation Exercise",
          description: "Speak about the prompt topic for 90 seconds total: First 30 seconds at SLOW pace (100 WPM), next 30 seconds at NORMAL pace (140-150 WPM), final 30 seconds at FAST pace (170-180 WPM). Notice how each speed feels.",
          duration_seconds: 90,
          drill_type: "variation_practice",
          icon: "🎵",
          target_reps: 1
        },
        {
          title: "Natural Pace Recording",
          description: "Speak naturally about the prompt for 2 minutes. After recording, count the total words you spoke. Divide by 2 to get your WPM. Ideal range: 130-170 WPM. Adjust in your next practice.",
          duration_seconds: 120,
          drill_type: "natural_practice",
          icon: "🗣️",
          target_reps: 1
        }
      ],
      "enhance_clarity" => [
        {
          title: "Articulation Warm-up",
          description: "Spend 20 seconds saying tongue twisters (e.g., 'She sells seashells'). Then speak about the prompt for 40 seconds, focusing on enunciating EVERY consonant clearly, especially at word endings (e.g., 'important' not 'importan').",
          duration_seconds: 60,
          drill_type: "articulation",
          icon: "👄",
          target_reps: 2
        },
        {
          title: "Clarity Recording Check",
          description: "Record yourself for 2 minutes explaining the prompt topic as if to someone who knows nothing about it. Speak 20% SLOWER than normal. Over-enunciate every word. Imagine you're speaking to someone across a noisy room.",
          duration_seconds: 120,
          drill_type: "clarity_check",
          icon: "🔍",
          target_reps: 1
        },
        {
          title: "Word Emphasis Exercise",
          description: "Speak about the prompt for 90 seconds. In EVERY sentence, identify the 2-3 most important words and emphasize them by speaking louder and clearer. Example: 'The PROJECT needs IMMEDIATE attention.' Feel the emphasis.",
          duration_seconds: 90,
          drill_type: "emphasis",
          icon: "💡",
          target_reps: 1
        }
      ],
      "boost_engagement" => [
        {
          title: "Energy & Tone Drill",
          description: "Speak about the prompt for 60 seconds. Vary your pitch: raise it for questions and exciting points, lower it for serious points. Vary your volume: louder for emphasis, softer for intimacy. Never use the same tone for more than 10 seconds.",
          duration_seconds: 60,
          drill_type: "energy_practice",
          icon: "⚡",
          target_reps: 2
        },
        {
          title: "Story Telling Practice",
          description: "Tell a story related to the prompt for 2 minutes. Use: 1) A dramatic opening, 2) Strategic 2-3 second pauses before key reveals, 3) Varied pacing (slow for tension, fast for excitement), 4) An emotional ending. Make it captivating!",
          duration_seconds: 120,
          drill_type: "storytelling",
          icon: "📖",
          target_reps: 1
        },
        {
          title: "Question Engagement",
          description: "Speak about the prompt for 90 seconds. Ask at least 3 rhetorical questions with rising intonation: 'What does this mean?' or 'Why is this important?' Pause 2 seconds after each question before answering it yourself.",
          duration_seconds: 90,
          drill_type: "engagement",
          icon: "❓",
          target_reps: 1
        }
      ],
      "increase_fluency" => [
        {
          title: "Impromptu Speaking Drill",
          description: "Start speaking about the prompt IMMEDIATELY without planning. Speak for 60 seconds without stopping, even if you make mistakes. Don't restart sentences—keep pushing forward. The goal is continuous flow, not perfection.",
          duration_seconds: 60,
          drill_type: "impromptu",
          icon: "🎲",
          target_reps: 2
        },
        {
          title: "Smooth Transitions Practice",
          description: "Speak for 2 minutes about the prompt. Make 5 distinct points. Connect each point with transition phrases: 'Building on that...', 'Similarly...', 'On the other hand...', 'This leads to...'. Practice seamless idea flow.",
          duration_seconds: 120,
          drill_type: "transitions",
          icon: "🔗",
          target_reps: 1
        },
        {
          title: "Fluency Flow Exercise",
          description: "Speak about the prompt for 90 seconds without ANY pauses longer than 2 seconds. If you lose your train of thought, use bridge phrases: 'What I mean is...', 'In other words...', 'The key point is...'. Never stop completely.",
          duration_seconds: 90,
          drill_type: "flow",
          icon: "🌊",
          target_reps: 1
        }
      ],
      "fix_long_pauses" => [
        {
          title: "Prepared Speaking Drill",
          description: "Before recording, write down 3-5 key points about the prompt. Then speak for 60 seconds using only your key points as reference. If you pause, glance at your notes and keep going. Limit pauses to maximum 2 seconds.",
          duration_seconds: 60,
          drill_type: "prepared",
          icon: "📝",
          target_reps: 2
        },
        {
          title: "Bridging Phrases Practice",
          description: "Speak for 90 seconds. Whenever you feel a pause coming, use a bridge phrase: 'So...', 'Well...', 'You see...', 'The thing is...', 'Essentially...'. These buy you thinking time without awkward silence. Use at least 5 bridges.",
          duration_seconds: 90,
          drill_type: "bridging",
          icon: "🌉",
          target_reps: 1
        },
        {
          title: "Outline-Based Recording",
          description: "Create a simple outline: 1) Opening statement, 2) Three supporting points, 3) Conclusion. Speak for 2 minutes following this structure. Move from section to section without pausing longer than 2 seconds. Structure prevents pauses.",
          duration_seconds: 120,
          drill_type: "outline",
          icon: "📋",
          target_reps: 1
        }
      ],
      "professional_language" => [
        {
          title: "Professional Vocabulary Drill",
          description: "Speak for 60 seconds about the prompt. Replace casual words: 'stuff' → 'matters', 'things' → 'elements', 'like' → 'such as', 'really' → 'significantly', 'get' → 'obtain/achieve'. Avoid contractions (say 'cannot' not 'can't').",
          duration_seconds: 60,
          drill_type: "vocabulary",
          icon: "💼",
          target_reps: 2
        },
        {
          title: "Business Presentation Practice",
          description: "Speak for 2 minutes as if presenting to executives. Start with: 'Today I'll discuss...'. Use formal phrases: 'I'd like to highlight...', 'The data indicates...', 'In conclusion...'. Maintain professional tone throughout. No slang.",
          duration_seconds: 120,
          drill_type: "presentation",
          icon: "📊",
          target_reps: 1
        },
        {
          title: "Formal Language Exercise",
          description: "Speak about the prompt for 90 seconds using complete sentences. Avoid: 'kinda', 'sorta', 'yeah', 'you know'. Instead use: 'somewhat', 'yes', 'as you're aware'. Pretend you're being recorded for a documentary. Be articulate.",
          duration_seconds: 90,
          drill_type: "formal",
          icon: "🎓",
          target_reps: 1
        }
      ]
    }.freeze

    # Default drills when no specific focus is set
    DEFAULT_DRILLS = [
      {
        title: "General Speaking Practice",
        description: "Practice speaking clearly on any topic for 60 seconds.",
        duration_seconds: 60,
        drill_type: "general",
        icon: "🎤",
        target_reps: 2
      },
      {
        title: "Fluency & Clarity Check",
        description: "Record yourself and review for overall fluency and clarity.",
        duration_seconds: 120,
        drill_type: "general_check",
        icon: "✓",
        target_reps: 1
      }
    ].freeze

    def initialize(weekly_focus, user)
      @weekly_focus = weekly_focus
      @user = user
      @today = Date.current
    end

    def generate_plan
      return generate_default_plan unless @weekly_focus.present?

      drills = get_drills_for_focus_type(@weekly_focus.focus_type)

      # Get today's completed sessions for this weekly focus
      completed_today = @user.sessions
                              .where(weekly_focus_id: @weekly_focus.id)
                              .where(completed: true)
                              .where("DATE(created_at) = ?", @today)
                              .count

      # Select appropriate number of drills (3-4 items for a 10-minute plan)
      selected_drills = select_drills(drills, completed_today)

      # Get recent session data for personalized reasoning
      recent_session_data = get_recent_session_data

      {
        total_duration_minutes: calculate_total_duration(selected_drills),
        estimated_time: "6–8 min / day",
        drills: selected_drills.map.with_index do |drill, index|
          drill.merge(
            order: index + 1,
            completed: false, # Will be updated based on actual session completion
            weekly_focus_id: @weekly_focus.id,
            reasoning: generate_drill_reasoning(drill, recent_session_data, index)
          )
        end
      }
    end

    private

    def get_drills_for_focus_type(focus_type)
      DRILL_TEMPLATES[focus_type] || DEFAULT_DRILLS
    end

    def select_drills(available_drills, completed_count)
      # For daily practice, select 3 drills:
      # - 2 primary drills from the focus area
      # - 1 supporting drill or review exercise

      primary_drills = available_drills.first(2)
      supporting_drill = available_drills[2] || available_drills.last

      [ primary_drills, supporting_drill ].flatten.compact.first(3)
    end

    def calculate_total_duration(drills)
      total_seconds = drills.sum { |drill| drill[:duration_seconds] }
      (total_seconds / 60.0).ceil
    end

    def generate_default_plan
      {
        total_duration_minutes: 3,
        estimated_time: "3–5 min / day",
        drills: DEFAULT_DRILLS.map.with_index do |drill, index|
          drill.merge(
            order: index + 1,
            completed: false,
            weekly_focus_id: nil,
            reasoning: "Complete more sessions to get personalized drill recommendations."
          )
        end
      }
    end

    def get_recent_session_data
      # Get last 3 sessions to analyze for personalized reasoning
      recent_sessions = @user.sessions
                              .where(completed: true)
                              .order(created_at: :desc)
                              .limit(3)
                              .includes(:issues)

      return nil if recent_sessions.empty?

      # Calculate averages and patterns
      {
        avg_filler_rate: recent_sessions.filter_map { |s| s.analysis_data["filler_rate"] }.sum / [ recent_sessions.count, 1 ].max,
        avg_wpm: recent_sessions.filter_map { |s| s.analysis_data["wpm"] }.sum / [ recent_sessions.count, 1 ].max,
        avg_clarity: recent_sessions.filter_map { |s| s.analysis_data["clarity_score"] }.sum / [ recent_sessions.count, 1 ].max,
        total_filler_issues: recent_sessions.sum { |s| s.issues.where(category: "filler_words").count },
        sessions_this_week: @user.sessions.where("created_at >= ?", @weekly_focus&.week_start || 1.week.ago).where(completed: true).count,
        target_sessions: @weekly_focus&.target_sessions_per_week || 10,
        starting_value: @weekly_focus&.starting_value,
        current_value: get_current_metric_value
      }
    end

    def get_current_metric_value
      return nil unless @weekly_focus

      recent_sessions = @user.sessions
                              .where(completed: true)
                              .order(created_at: :desc)
                              .limit(5)

      case @weekly_focus.focus_type
      when "reduce_fillers"
        values = recent_sessions.filter_map { |s| s.analysis_data["filler_rate"] }
        values.sum / [ values.count, 1 ].max
      when "improve_pace"
        values = recent_sessions.filter_map { |s| s.analysis_data["wpm"] }
        values.sum / [ values.count, 1 ].max
      when "enhance_clarity"
        values = recent_sessions.filter_map { |s| s.analysis_data["clarity_score"] }
        values.sum / [ values.count, 1 ].max
      else
        @weekly_focus.starting_value
      end
    end

    def generate_drill_reasoning(drill, session_data, drill_index)
      return nil unless session_data.present?

      focus_type = @weekly_focus.focus_type

      # Generate reasoning based on focus type and user's recent data
      case focus_type
      when "reduce_fillers"
        if drill_index == 0
          filler_percent = (session_data[:avg_filler_rate] * 100).round(1)
          issue_count = session_data[:total_filler_issues]
          "In your last 3 sessions, you used an average of #{filler_percent}% filler words (#{issue_count} total occurrences). This drill teaches you to pause confidently instead."
        elsif drill_index == 1
          progress = calculate_weekly_progress(session_data)
          "You've completed #{session_data[:sessions_this_week]}/#{session_data[:target_sessions]} sessions this week. #{progress}"
        else
          "Awareness is key—tracking your fillers helps you identify when they happen most."
        end

      when "improve_pace"
        if drill_index == 0
          current_wpm = session_data[:avg_wpm].round
          target_wpm = @weekly_focus.target_value.round
          "Your recent pace is #{current_wpm} WPM. This drill helps you adjust to the ideal range of #{target_wpm} WPM."
        elsif drill_index == 1
          "Varying your pace prevents monotone delivery and keeps your audience engaged."
        else
          "Finding your natural, sustainable pace takes practice. Let's build that muscle memory."
        end

      when "enhance_clarity"
        if drill_index == 0
          clarity_percent = (session_data[:avg_clarity] * 100).round
          "Your recent clarity score is #{clarity_percent}%. Articulation warm-ups prepare your mouth muscles for clear speech."
        elsif drill_index == 1
          progress = calculate_weekly_progress(session_data)
          "#{progress} Keep recording to track your clarity improvement."
        else
          "Emphasizing key words helps listeners follow your message more easily."
        end

      when "boost_engagement", "increase_fluency"
        if drill_index == 0
          improvement_area = focus_type == "boost_engagement" ? "energy" : "fluency"
          "Adding vocal variety and #{improvement_area} makes your speech more compelling and easier to follow."
        elsif drill_index == 1
          progress = calculate_weekly_progress(session_data)
          "#{progress} Each session builds your confidence."
        else
          "Practice makes permanent—the more you rehearse these techniques, the more natural they become."
        end

      when "fix_long_pauses", "professional_language"
        if drill_index == 0
          issue_type = focus_type == "fix_long_pauses" ? "long pauses" : "casual language"
          "Your recent sessions showed opportunities to improve #{issue_type}. This drill addresses that directly."
        else
          progress = calculate_weekly_progress(session_data)
          "#{progress} You're on track!"
        end

      else
        "This drill is designed to help you improve in your focus area. Practice consistently for best results."
      end
    end

    def calculate_weekly_progress(session_data)
      return "" unless session_data[:starting_value] && session_data[:current_value]

      start_val = session_data[:starting_value]
      current_val = session_data[:current_value]

      # Determine if lower is better (e.g., filler rate)
      inverse = @weekly_focus.focus_type == "reduce_fillers"

      if inverse
        if current_val < start_val
          improvement = ((start_val - current_val) / start_val * 100).round
          "Great progress! You've improved by #{improvement}% from where you started."
        else
          "Keep practicing—consistency is key to reducing this metric."
        end
      else
        if current_val > start_val
          improvement = ((current_val - start_val) / start_val * 100).round
          "Excellent! You've improved by #{improvement}% from your starting point."
        else
          "You're building the foundation. Keep going!"
        end
      end
    end
  end
end
