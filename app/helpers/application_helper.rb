module ApplicationHelper
  # Extract filler word from issue's coaching_note field
  def extract_filler_word(issue)
    return nil unless issue.kind == "filler_word" && issue.source == "ai"
    issue.coaching_note
  end

  def highlight_filler_words(transcript_text, ai_filler_words = [])
    return "" unless transcript_text.present?

    highlighted_text = transcript_text.dup

    # Use AI detections if available, otherwise fallback to regex
    if ai_filler_words.any?
      # AI is primary - highlight only AI-detected filler words
      ai_filler_words.each do |filler_word|
        next if filler_word.blank?

        # Escape special regex characters and create word boundary pattern
        escaped_word = Regexp.escape(filler_word)
        ai_pattern = /\b#{escaped_word}\b/i

        highlighted_text.gsub!(ai_pattern) do |match|
          %(<span class="filler-word filler-ai">#{match}</span>)
        end
      end
    else
      # Fallback to regex patterns only when AI failed or returned no results
      filler_patterns = {
        "um" => /\b(um|uhm)\b/i,
        "uh" => /\b(uh|er|ah)\b/i,
        "like" => /\blike\b/i,
        "you_know" => /\byou know\b/i,
        "basically" => /\bbasically\b/i,
        "actually" => /\bactually\b/i,
        "so" => /\bso\b(?!\s+(that|what|how|when|where|why))/i
      }

      filler_patterns.each do |type, pattern|
        highlighted_text.gsub!(pattern) do |match|
          %(<span class="filler-word filler-#{type}">#{match}</span>)
        end
      end
    end

    # Use simple_format to preserve line breaks and paragraphs
    simple_format(highlighted_text).html_safe
  end

  def metric_tooltip(metric_name, explanation, options = {})
    position = options[:position] || "top"

    content_tag(:span, class: "metric-with-tooltip", data: { controller: "tooltip", tooltip_position_value: position }) do
      concat content_tag(:span, metric_name, class: "metric-name-text")
      concat content_tag(:button, "ⓘ",
        type: "button",
        class: "tooltip-trigger",
        data: {
          action: "mouseenter->tooltip#show mouseleave->tooltip#hide click->tooltip#toggle"
        },
        aria: { label: "Show explanation for #{metric_name}" }
      )
      concat content_tag(:div, explanation,
        class: "tooltip-content hidden",
        data: { tooltip_target: "content" },
        role: "tooltip"
      )
    end
  end
end
