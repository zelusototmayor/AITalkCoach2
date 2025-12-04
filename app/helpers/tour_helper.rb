module TourHelper
  # Tour step definitions for each page
  TOUR_DEFINITIONS = {
    "practice" => {
      name: "practice",
      steps: [
        {
          target: '[data-tour="sidebar"]',
          title: "Navigation",
          content: "Use the sidebar to navigate between different sections of the app. You can access your Practice area, Coach insights, Progress tracking, session Reports, and browse Prompts.",
          position: "right"
        },
        {
          target: '[data-tour="prompt-card"]',
          title: "Your Speaking Prompt",
          content: "This is your current speaking prompt. It shows the topic you'll be speaking about, along with the difficulty level and target duration.",
          position: "bottom"
        },
        {
          target: '[data-tour="record-button"]',
          title: "Start Recording",
          content: "When you're ready, click this button to start recording. Speak naturally about the prompt topic - there's no right or wrong answer!",
          position: "top"
        }
      ]
    },
    "session_results" => {
      name: "session_results",
      steps: [
        {
          target: '[data-tour="media-player"]',
          title: "Replay Your Recording",
          content: "Listen back to your recording anytime. This helps you hear your speaking patterns and identify areas to work on.",
          position: "bottom"
        },
        {
          target: '[data-tour="transcript"]',
          title: "Your Transcript",
          content: "We've transcribed everything you said. Review it to see your actual words and identify filler words or areas to improve.",
          position: "bottom"
        },
        {
          target: '[data-tour="metrics"]',
          title: "Performance Metrics",
          content: "These cards show how you performed across key speaking areas: clarity, pace, filler words, fluency, and more. Click any metric to learn more about it.",
          position: "left"
        },
        {
          target: '[data-tour="coach-recommendations"]',
          title: "AI Coach Tips",
          content: "Your AI coach analyzes your session and provides personalized recommendations to help you improve.",
          position: "top"
        },
        {
          target: '[data-tour="trends"]',
          title: "Track Your Progress",
          content: "After a few more sessions, you'll see trend data here showing how you're improving over time.",
          position: "top"
        }
      ]
    },
    "coach" => {
      name: "coach",
      steps: [
        {
          target: '[data-tour="insight-card"]',
          title: "Session Insights",
          content: "Get a quick summary of your most recent practice session with key highlights and observations.",
          position: "bottom"
        },
        {
          target: '[data-tour="metrics-grid"]',
          title: "Your Metrics Overview",
          content: "See all your key speaking metrics at a glance. Each card shows your current performance and recent trends.",
          position: "top"
        },
        {
          target: '[data-tour="weekly-goals"]',
          title: "Weekly Goals",
          content: "Your coach sets personalized weekly goals based on your performance. Track your progress toward becoming a better speaker.",
          position: "left"
        },
        {
          target: '[data-tour="todays-focus"]',
          title: "Today's Focus",
          content: "These are your personalized drills for today. Complete them to build consistent practice habits and improve faster.",
          position: "top"
        }
      ]
    },
    "progress" => {
      name: "progress",
      steps: [
        {
          target: '[data-tour="progress-chart"]',
          title: "Your Progress Chart",
          content: "This chart shows your improvement over time. Watch your scores climb as you practice consistently!",
          position: "bottom"
        },
        {
          target: '[data-tour="time-filters"]',
          title: "Change Time Range",
          content: "Switch between different time ranges to see your short-term gains or long-term improvement trends.",
          position: "bottom"
        },
        {
          target: '[data-tour="metric-cards"]',
          title: "Detailed Metrics",
          content: "Click on any metric card to see detailed progress for that specific area. Each metric tracks a different aspect of your speaking skills.",
          position: "top"
        }
      ]
    }
  }.freeze

  # Determine which tour should be shown for the current page
  def current_tour_name
    return nil unless logged_in? && current_user.onboarding_completed?

    tour_name = case controller_name
                when "sessions"
                  case action_name
                  when "index" then "practice"
                  when "show" then "session_results"
                  when "coach" then "coach"
                  when "progress" then "progress"
                  end
                end

    return nil unless tour_name
    return nil if current_user.tour_completed?(tour_name)

    tour_name
  end

  # Check if we should show a tour on current page
  def should_show_tour?
    current_tour_name.present?
  end

  # Get tour steps as JSON for JavaScript
  def tour_steps_json(tour_name)
    tour = TOUR_DEFINITIONS[tour_name]
    return "[]" unless tour

    tour[:steps].to_json
  end

  # Get tour configuration for rendering
  def current_tour_config
    tour_name = current_tour_name
    return nil unless tour_name

    TOUR_DEFINITIONS[tour_name]
  end
end
