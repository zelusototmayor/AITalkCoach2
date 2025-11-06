module Analysis
  class RelevanceChecker
    class RelevanceCheckError < StandardError; end

    # Use faster, cheaper model for quick relevance checks
    RELEVANCE_MODEL = ENV["AI_MODEL_RELEVANCE"] || "gpt-4o-mini"

    # Relevance score threshold for determining off-topic responses
    # Set generously to avoid false positives
    DEFAULT_RELEVANCE_THRESHOLD = 0.6

    def initialize(session, options = {})
      @session = session
      @options = options
      @ai_client = Ai::Client.new(model: RELEVANCE_MODEL)
      @threshold = options[:threshold] || DEFAULT_RELEVANCE_THRESHOLD
    end

    def check_relevance(transcript_data)
      start_time = Time.current

      transcript_text = extract_transcript_text(transcript_data)
      # Use prompt_text if available, fallback to title
      prompt_text = @session.prompt_text.presence || @session.title
      language = @session.language || "en"

      result = {
        on_topic: true,
        relevance_score: 1.0,
        feedback: nil,
        processing_time_ms: 0
      }

      # Skip check if no prompt or transcript
      if prompt_text.blank? || transcript_text.blank?
        Rails.logger.warn "RelevanceChecker: Skipping check - missing prompt or transcript"
        return result
      end

      begin
        messages = build_relevance_check_messages(prompt_text, transcript_text, language)
        response = @ai_client.chat_completion(messages, temperature: 0.3)

        parsed_result = parse_relevance_response(response)

        result.merge!(
          on_topic: parsed_result[:relevance_score] >= @threshold,
          relevance_score: parsed_result[:relevance_score],
          feedback: parsed_result[:feedback],
          processing_time_ms: ((Time.current - start_time) * 1000).round
        )

        Rails.logger.info "RelevanceChecker: Score=#{result[:relevance_score]}, On-topic=#{result[:on_topic]}"

      rescue StandardError => e
        Rails.logger.error "RelevanceChecker: Error during relevance check - #{e.message}"
        Rails.logger.error e.backtrace.join("\n")

        # On error, assume on-topic to avoid blocking user
        result[:on_topic] = true
        result[:relevance_score] = 1.0
        result[:feedback] = "Unable to check relevance - proceeding with analysis"
      end

      result
    end

    private

    def extract_transcript_text(transcript_data)
      if transcript_data.is_a?(Hash)
        transcript_data.dig("results", "channels", 0, "alternatives", 0, "transcript") ||
          transcript_data["transcript"] ||
          transcript_data[:transcript] ||
          ""
      else
        transcript_data.to_s
      end
    end

    def build_relevance_check_messages(prompt_text, transcript_text, language)
      language_instruction = case language
      when "pt", "pt-BR"
        "The prompt and response are in Portuguese."
      when "es"
        "The prompt and response are in Spanish."
      else
        "The prompt and response are in English."
      end

      system_prompt = <<~PROMPT
        You are evaluating whether a spoken response addresses the core intent of a prompt.

        Your job is to be GENEROUS and LENIENT. Only flag responses that clearly miss the main point.

        Guidelines:
        - Open-ended prompts allow broad answers - be flexible
        - Creative interpretations are usually valid
        - Only flag if the response is clearly unrelated or misses the core question
        - Consider cultural and linguistic nuances

        #{language_instruction}

        Respond with a JSON object containing:
        {
          "relevance_score": <float between 0.0 and 1.0>,
          "feedback": "<brief explanation of what was missed, if anything>"
        }

        Score guidelines:
        - 0.9-1.0: Fully addresses the prompt
        - 0.7-0.8: Addresses most of the prompt, minor gaps
        - 0.5-0.6: Partially on-topic but misses key elements
        - 0.0-0.4: Clearly off-topic or doesn't address the prompt
      PROMPT

      user_prompt = <<~PROMPT
        Prompt: "#{prompt_text}"

        Response: "#{transcript_text}"

        Does this response address the prompt's core intent? Provide your evaluation as JSON.
      PROMPT

      [
        { role: "system", content: system_prompt },
        { role: "user", content: user_prompt }
      ]
    end

    def parse_relevance_response(response)
      # The AI client already parses the response for us
      # Check if we have parsed_content (new format) or need to parse manually (old format)
      if response[:parsed_content].present?
        parsed = response[:parsed_content]
        return {
          relevance_score: parsed["relevance_score"].to_f,
          feedback: parsed["feedback"]
        }
      end

      # Fallback: try old format with choices/message/content
      content = response.dig(:choices, 0, :message, :content) || response[:content]

      if content.blank?
        Rails.logger.error "RelevanceChecker: Content is blank. Response keys: #{response.keys.inspect}"
        raise RelevanceCheckError, "Empty response from AI"
      end

      # Parse JSON response
      begin
        parsed = JSON.parse(content)

        {
          relevance_score: parsed["relevance_score"].to_f,
          feedback: parsed["feedback"]
        }
      rescue JSON::ParserError => e
        Rails.logger.error "RelevanceChecker: Failed to parse JSON response - #{e.message}"
        Rails.logger.error "Response content: #{content}"

        # Try to extract score from text as fallback
        if content.match(/score[:\s]*([0-9.]+)/i)
          score = $1.to_f
          { relevance_score: score, feedback: "Response parsed from text" }
        else
          raise RelevanceCheckError, "Unable to parse relevance response"
        end
      end
    end
  end
end
