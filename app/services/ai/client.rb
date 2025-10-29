module Ai
  class Client
    class ClientError < StandardError; end
    class RateLimitError < ClientError; end
    class AuthenticationError < ClientError; end
    class QuotaExceededError < ClientError; end

    BASE_URL = "https://api.openai.com/v1"
    RETRY_ATTEMPTS = 3
    RETRY_DELAY = 1.0
    MAX_TOKENS = 4000
    TEMPERATURE = 0.3

    def initialize(api_key: nil, model: "gpt-4")
      @api_key = api_key || ENV["OPENAI_API_KEY"]
      @model = model

      if @api_key.blank?
        raise ArgumentError, "OpenAI API key is required"
      end
    end

    def chat_completion(messages, options = {})
      default_options = {
        model: @model,
        messages: messages,
        max_completion_tokens: MAX_TOKENS
      }

      # Only add temperature if explicitly provided in options
      # Some models (like o1) don't support custom temperature
      if options.key?(:temperature)
        default_options[:temperature] = options[:temperature]
      end

      # NEW: Add tools (function calling) if schema provided
      if options[:tool_schema] && options[:prompt_type]
        tools = [ build_function_definition(options[:prompt_type], options[:tool_schema]) ]
        default_options[:tools] = tools
        default_options[:tool_choice] = {
          type: "function",
          function: { name: function_name_for_prompt_type(options[:prompt_type]) }
        }

        # Log schema for debugging
        Rails.logger.info "OpenAI Function Call - Type: #{options[:prompt_type]}, Schema: #{options[:tool_schema].to_json}"
      # FALLBACK: Use JSON mode for compatible models (when not using function calling)
      # Don't use JSON mode if function calling is available - it's not needed
      elsif supports_json_mode?(@model) && !options[:tool_schema] && json_mode_requested?(messages)
        default_options[:response_format] = { type: "json_object" }
      end

      merged_options = default_options.merge(options.except(:temperature, :tool_schema, :prompt_type))

      # Estimate token usage for rate limiting
      estimated_tokens = estimate_token_usage(messages, merged_options[:max_completion_tokens] || merged_options[:max_tokens])

      # Use enhanced retry mechanism with rate limiting
      retry_handler = Networking::RetryHandler.new(:ai_generation)

      retry_handler.with_retries(service: "openai", endpoint: "chat/completions", estimated_tokens: estimated_tokens) do
        # Check rate limits before making request
        rate_limiter = Networking::RateLimiter.new(:openai)
        rate_limiter.check_rate_limit!("chat/completions", tokens: estimated_tokens)

        response = send_chat_request(merged_options)
        parsed_response = parse_chat_response(response, options[:prompt_type])

        # Record actual token usage
        actual_tokens = parsed_response.dig(:usage, :total_tokens)
        rate_limiter.record_api_response(response, tokens_used: actual_tokens)

        parsed_response
      end
    end

    def analyze_speech_segment(transcript_text, context = {})
      system_prompt = build_speech_analysis_system_prompt
      user_prompt = build_speech_analysis_user_prompt(transcript_text, context)

      messages = [
        { role: "system", content: system_prompt },
        { role: "user", content: user_prompt }
      ]

      # Note: o1 models (gpt-5) don't support custom temperature - use default
      chat_completion(messages)
    end

    def classify_speech_issues(issues_data, context = {})
      system_prompt = build_issue_classification_system_prompt
      user_prompt = build_issue_classification_user_prompt(issues_data, context)

      messages = [
        { role: "system", content: system_prompt },
        { role: "user", content: user_prompt }
      ]

      # Note: o1 models (gpt-5) don't support custom temperature - use default
      chat_completion(messages)
    end

    def generate_coaching_advice(user_profile, recent_issues)
      system_prompt = build_coaching_system_prompt
      user_prompt = build_coaching_user_prompt(user_profile, recent_issues)

      messages = [
        { role: "system", content: system_prompt },
        { role: "user", content: user_prompt }
      ]

      # Note: o1 models (gpt-5) don't support custom temperature - use default
      chat_completion(messages, max_completion_tokens: 1000)
    end

    def create_embedding(text, model: "text-embedding-3-small")
      # Use enhanced retry mechanism with rate limiting
      retry_handler = Networking::RetryHandler.new(:ai_generation)

      retry_handler.with_retries(service: "openai", endpoint: "embeddings") do
        # Check rate limits before making request
        rate_limiter = Networking::RateLimiter.new(:openai)
        rate_limiter.check_rate_limit!("embeddings")

        response = send_embedding_request(text, model)
        parsed_response = parse_embedding_response(response)

        # Record response for rate limit tracking
        rate_limiter.record_api_response(response)

        parsed_response
      end
    end

    private

    def supports_json_mode?(model)
      # Models that support structured JSON output
      json_supported_models = %w[gpt-4o gpt-4o-mini gpt-4-turbo gpt-4-turbo-preview gpt-3.5-turbo-1106]
      json_supported_models.any? { |supported| model.include?(supported) }
    end

    def send_chat_request(options)
      HTTP.auth("Bearer #{@api_key}")
          .headers("Content-Type" => "application/json")
          .timeout(connect: 30, read: 120)
          .post("#{BASE_URL}/chat/completions", json: options)
    end

    def send_embedding_request(text, model)
      options = {
        model: model,
        input: text
      }

      HTTP.auth("Bearer #{@api_key}")
          .headers("Content-Type" => "application/json")
          .timeout(connect: 30, read: 60)
          .post("#{BASE_URL}/embeddings", json: options)
    end

    def parse_chat_response(response, prompt_type = nil)
      handle_response_errors(response)

      data = JSON.parse(response.body.to_s)

      unless data["choices"] && data["choices"].first
        raise ClientError, "Invalid response format from OpenAI"
      end

      choice = data["choices"].first

      # NEW: Check for tool_calls first (function calling response)
      if choice["message"]["tool_calls"]&.any?
        tool_call = choice["message"]["tool_calls"].first

        if tool_call["function"]
          arguments_json = tool_call["function"]["arguments"]
          parsed_content = JSON.parse(arguments_json)

          Rails.logger.info "Function calling response received: #{tool_call['function']['name']}"

          return {
            content: arguments_json,
            parsed_content: parsed_content,
            usage: data["usage"],
            model: data["model"],
            finish_reason: choice["finish_reason"],
            tool_call_id: tool_call["id"],
            function_name: tool_call["function"]["name"]
          }
        end
      end

      # FALLBACK: Standard message content parsing (backward compatible)
      content = choice["message"]["content"]

      {
        content: content,
        parsed_content: safe_json_parse(content),
        usage: data["usage"],
        model: data["model"],
        finish_reason: choice["finish_reason"]
      }
    rescue JSON::ParserError => e
      raise ClientError, "Failed to parse response: #{e.message}"
    end

    def parse_embedding_response(response)
      handle_response_errors(response)

      data = JSON.parse(response.body.to_s)

      unless data["data"] && data["data"].first
        raise ClientError, "Invalid embedding response format from OpenAI"
      end

      {
        embedding: data["data"].first["embedding"],
        usage: data["usage"],
        model: data["model"]
      }
    rescue JSON::ParserError => e
      raise ClientError, "Failed to parse embedding response: #{e.message}"
    end

    def handle_response_errors(response)
      case response.status
      when 200..299
        # Success - continue processing
      when 400
        error_msg = extract_error_message(response)
        raise ClientError, "Bad request: #{error_msg}"
      when 401
        raise AuthenticationError, "Invalid API key or authentication failed"
      when 403
        error_msg = extract_error_message(response)
        raise ClientError, "Forbidden: #{error_msg}"
      when 429
        error_msg = extract_error_message(response)
        if error_msg.include?("quota")
          raise QuotaExceededError, "Quota exceeded: #{error_msg}"
        else
          raise RateLimitError, "Rate limit exceeded: #{error_msg}"
        end
      when 500..599
        raise ClientError, "OpenAI server error (#{response.status})"
      else
        raise ClientError, "Unexpected response status: #{response.status}"
      end
    end

    def extract_error_message(response)
      data = JSON.parse(response.body.to_s)
      data.dig("error", "message") || response.body.to_s
    rescue JSON::ParserError
      response.body.to_s
    end

    def safe_json_parse(content)
      JSON.parse(content)
    rescue JSON::ParserError
      nil
    end

    def estimate_token_usage(messages, max_tokens)
      # Simple token estimation: roughly 4 characters per token
      # This is a rough approximation - actual tokenization would be more accurate
      total_chars = messages.sum { |msg| msg[:content].to_s.length }
      input_tokens = (total_chars / 4.0).ceil

      # Add estimated output tokens (use max_tokens as upper bound)
      output_tokens = [ max_tokens, 1000 ].min # Cap at reasonable output size

      input_tokens + output_tokens
    end

    def build_speech_analysis_system_prompt
      <<~PROMPT
        You are an expert speech coach and communication trainer. Your role is to analyze speech segments and provide constructive feedback.

        Analyze the provided speech transcript and identify areas for improvement in:
        1. Clarity and articulation
        2. Professional language use
        3. Confidence and assertiveness
        4. Engagement and energy
        5. Structure and flow

        Return your analysis as JSON with this exact structure:
        {
          "overall_score": 85,
          "areas_of_strength": ["Clear articulation", "Good energy"],
          "areas_for_improvement": ["Reduce filler words", "Vary pace"],
          "specific_feedback": [
            {
              "issue": "filler_words",
              "confidence": 0.8,
              "recommendation": "Try pausing instead of using 'um'",
              "priority": "medium"
            }
          ],
          "coaching_tips": ["Practice with recording yourself"]
        }
      PROMPT
    end

    def build_speech_analysis_user_prompt(transcript_text, context)
      prompt = "Please analyze this speech transcript:\n\n"
      prompt += "\"#{transcript_text}\"\n\n"

      if context[:target_audience]
        prompt += "Target audience: #{context[:target_audience]}\n"
      end

      if context[:speech_type]
        prompt += "Speech type: #{context[:speech_type]}\n"
      end

      if context[:duration_seconds]
        prompt += "Duration: #{context[:duration_seconds]} seconds\n"
      end

      prompt += "\nProvide detailed feedback following the JSON structure specified."
      prompt
    end

    def build_issue_classification_system_prompt
      <<~PROMPT
        You are a speech analysis classifier. Your task is to review detected speech issues and classify them with confidence scores.

        For each issue, provide:
        1. Confidence score (0.0-1.0) for the detection accuracy
        2. Severity level (low/medium/high)
        3. Improved description if needed
        4. Actionable coaching tip
        5. Priority for addressing (low/medium/high)

        Return results as JSON with this structure:
        {
          "classified_issues": [
            {
              "original_issue": "filler_word",
              "confidence": 0.9,
              "severity": "medium",
              "description": "Frequent use of 'um' disrupts flow",
              "coaching_tip": "Practice pausing for 1-2 seconds instead",
              "priority": "medium",
              "recommended_practice": "Record yourself daily for a week"
            }
          ],
          "summary": {
            "total_issues": 5,
            "high_priority": 1,
            "medium_priority": 3,
            "low_priority": 1
          }
        }
      PROMPT
    end

    def build_issue_classification_user_prompt(issues_data, context)
      prompt = "Please classify these detected speech issues:\n\n"

      issues_data.each_with_index do |issue, index|
        prompt += "Issue #{index + 1}:\n"
        prompt += "- Type: #{issue[:kind]}\n"
        prompt += "- Text: \"#{issue[:text]}\"\n"
        prompt += "- Current severity: #{issue[:severity]}\n"
        prompt += "- Rationale: #{issue[:rationale]}\n\n"
      end

      if context[:user_level]
        prompt += "User level: #{context[:user_level]}\n"
      end

      prompt += "Classify each issue with confidence and provide actionable advice."
      prompt
    end

    def build_coaching_system_prompt
      <<~PROMPT
        You are a personalized speech coach. Create tailored coaching advice based on the user's speaking patterns and recent performance.

        Provide coaching that is:
        1. Specific to their recurring issues
        2. Progressive (building on previous sessions)
        3. Actionable with clear next steps
        4. Encouraging while being constructive

        Return advice as JSON:
        {
          "personalized_focus_areas": ["pace_control", "filler_reduction"],
          "this_week_goals": [
            {
              "goal": "Reduce 'um' usage by 50%",
              "strategy": "Practice with 2-second pauses",
              "measurement": "Track filler count per session"
            }
          ],
          "practice_exercises": [
            {
              "exercise": "Mirror practice",
              "duration": "10 minutes daily",
              "focus": "Watch facial expressions while speaking"
            }
          ],
          "motivation_message": "You've improved clarity by 15% this week!"
        }
      PROMPT
    end

    def build_coaching_user_prompt(user_profile, recent_issues)
      prompt = "Create personalized coaching advice for this user:\n\n"

      prompt += "User Profile:\n"
      prompt += "- Sessions completed: #{user_profile[:sessions_count]}\n"
      prompt += "- Primary goals: #{user_profile[:goals]&.join(', ')}\n"
      prompt += "- Experience level: #{user_profile[:level]}\n\n"

      prompt += "Recent Issues Pattern:\n"
      recent_issues.each do |issue_type, count|
        prompt += "- #{issue_type}: #{count} occurrences\n"
      end

      prompt += "\nCreate specific, actionable coaching advice for their next practice session."
      prompt
    end

    # Function calling (Tools API) support for GPT-5
    def build_function_definition(prompt_type, schema)
      {
        type: "function",
        function: {
          name: function_name_for_prompt_type(prompt_type),
          description: function_description_for_prompt_type(prompt_type),
          parameters: convert_schema_to_openai_format(schema),
          strict: true  # Enable strict mode for guaranteed structure
        }
      }
    end

    def function_name_for_prompt_type(prompt_type)
      {
        "filler_word_detection" => "detect_filler_words",
        "speech_analysis" => "analyze_speech_segment",
        "issue_classification" => "classify_speech_issues",
        "coaching_advice" => "provide_coaching_advice",
        "segment_evaluation" => "evaluate_segment",
        "progress_assessment" => "assess_progress"
      }[prompt_type] || "process_speech"
    end

    def function_description_for_prompt_type(prompt_type)
      {
        "filler_word_detection" => "Detect and analyze filler words in speech transcript",
        "speech_analysis" => "Analyze speech segment quality and provide coaching feedback",
        "issue_classification" => "Classify and validate detected speech issues",
        "coaching_advice" => "Generate personalized coaching recommendations",
        "segment_evaluation" => "Evaluate speech segment for AI analysis potential",
        "progress_assessment" => "Assess user progress over time"
      }[prompt_type] || "Process speech data"
    end

    def convert_schema_to_openai_format(schema)
      # OpenAI strict mode requires additionalProperties: false on ALL nested objects
      # and explicit items definition for all arrays
      deep_dup_and_fix_schema(schema)
    end

    def deep_dup_and_fix_schema(obj)
      case obj
      when Hash
        result = obj.each_with_object({}) { |(k, v), h| h[k] = deep_dup_and_fix_schema(v) }

        # Add additionalProperties: false to all objects (required by strict mode)
        if result[:type] == "object" || result[:type] == :object
          result[:additionalProperties] = false unless result.key?(:additionalProperties)
        end

        result
      when Array
        obj.map { |v| deep_dup_and_fix_schema(v) }
      else
        obj.duplicable? ? obj.dup : obj
      end
    end

    # Kept for backward compatibility
    def deep_dup_schema(obj)
      deep_dup_and_fix_schema(obj)
    end

    def json_mode_requested?(messages)
      # Check if any message contains the word "json" (required for JSON mode)
      messages.any? { |msg| msg[:content].to_s.downcase.include?("json") }
    end
  end
end
