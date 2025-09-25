module ApplicationHelper
  def highlight_filler_words(transcript_text)
    return '' unless transcript_text.present?

    # Define filler word patterns (same as in metrics.rb)
    filler_patterns = {
      'um' => /\b(um|uhm)\b/i,
      'uh' => /\b(uh|er|ah)\b/i,
      'like' => /\blike\b/i,
      'you_know' => /\byou know\b/i,
      'basically' => /\bbasically\b/i,
      'actually' => /\bactually\b/i,
      'so' => /\bso\b(?!\s+(that|what|how|when|where|why))/i
    }

    # Process the text and wrap filler words in spans
    highlighted_text = transcript_text.dup

    filler_patterns.each do |type, pattern|
      highlighted_text.gsub!(pattern) do |match|
        %(<span class="filler-word filler-#{type}">#{match}</span>)
      end
    end

    # Use simple_format to preserve line breaks and paragraphs
    simple_format(highlighted_text).html_safe
  end
end
