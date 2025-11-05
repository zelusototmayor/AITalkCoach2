module Stt
  class DeepgramClient
    class TranscriptionError < StandardError; end
    class RateLimitError < TranscriptionError; end
    class AuthenticationError < TranscriptionError; end

    BASE_URL = "https://api.deepgram.com/v1/listen"
    RETRY_ATTEMPTS = 3
    RETRY_DELAY = 1.0

    def initialize(api_key: nil)
      @api_key = api_key || ENV["DEEPGRAM_API_KEY"]

      if @api_key.blank?
        raise ArgumentError, "Deepgram API key is required"
      end
    end

    def transcribe_file(file_path, options = {})
      validate_file!(file_path)

      default_options = {
        model: "nova-3",
        language: "en-US",
        punctuate: true,
        diarize: false,
        paragraphs: true,
        utterances: true,
        utt_split: 0.8,
        smart_format: true,
        filler_words: true,
        profanity_filter: false
      }

      merged_options = default_options.merge(options)

      # Map language code to Deepgram format
      if merged_options[:language]
        merged_options[:language] = map_language_code(merged_options[:language])
      end

      # Use enhanced retry mechanism with rate limiting
      retry_handler = Networking::RetryHandler.new(:api_call)

      retry_handler.with_retries(service: "deepgram", endpoint: "transcribe_file") do
        # Check rate limits before making request
        rate_limiter = Networking::RateLimiter.new(:deepgram)
        rate_limiter.check_rate_limit!("transcribe")

        response = send_transcription_request(file_path, merged_options)
        parsed_response = parse_transcription_response(response)

        # Record response for rate limit tracking
        rate_limiter.record_api_response(response)

        parsed_response
      end
    end

    def transcribe_url(audio_url, options = {})
      default_options = {
        model: "nova-3",
        language: "en-US",
        punctuate: true,
        diarize: false,
        paragraphs: true,
        utterances: true,
        utt_split: 0.8,
        smart_format: true,
        filler_words: true,
        profanity_filter: false
      }

      merged_options = default_options.merge(options)

      # Map language code to Deepgram format
      if merged_options[:language]
        merged_options[:language] = map_language_code(merged_options[:language])
      end

      with_retries do
        response = send_url_transcription_request(audio_url, merged_options)
        parse_transcription_response(response)
      end
    end

    private

    def map_language_code(lang)
      # Use LanguageService if available for dynamic mapping
      if defined?(LanguageService) && LanguageService.language_supported?(lang)
        return LanguageService.deepgram_code(lang)
      end

      # Fallback to hardcoded mappings for backward compatibility
      case lang
      when "pt" then "pt-PT"    # Portuguese (Portugal)
      when "en" then "en-US"    # English (US)
      when "es" then "es-US"    # Spanish (US)
      when "fr" then "fr-FR"    # French (France)
      when "de" then "de-DE"    # German (Germany)
      when "it" then "it-IT"    # Italian (Italy)
      when "nl" then "nl"       # Dutch
      when "sv" then "sv-SE"    # Swedish (Sweden)
      when "da" then "da-DK"    # Danish (Denmark)
      when "no" then "no"       # Norwegian
      when "tr" then "tr"       # Turkish
      else lang                 # Pass through if already in correct format
      end
    end

    def send_transcription_request(file_path, options)
      url = build_url(options)
      content_type = content_type_for_file(file_path)
      file_size = File.size(file_path)

      Rails.logger.info "Deepgram API Request - URL: #{url}"
      Rails.logger.info "Deepgram API Request - File: #{file_path} (#{file_size} bytes)"
      Rails.logger.info "Deepgram API Request - Content-Type: #{content_type}"
      Rails.logger.info "Deepgram API Request - API Key: #{@api_key[0..5]}...#{@api_key[-4..-1]}"

      File.open(file_path, "rb") do |file|
        response = HTTP.auth("Token #{@api_key}")
            .headers("Content-Type" => content_type)
            .timeout(connect: 30, write: 180, read: 120)
            .post(url, body: file)

        Rails.logger.info "Deepgram API Response - Status: #{response.status}"
        Rails.logger.info "Deepgram API Response - Headers: #{response.headers.to_h}"
        Rails.logger.info "Deepgram API Response - Body: #{response.body.to_s[0..500]}..."

        response
      end
    end

    def send_url_transcription_request(audio_url, options)
      url = build_url(options)
      body = { url: audio_url }

      HTTP.auth("Token #{@api_key}")
          .headers("Content-Type" => "application/json")
          .timeout(connect: 30, write: 180, read: 120)
          .post(url, json: body)
    end

    def build_url(options)
      query_params = options.map { |k, v| "#{k}=#{v}" }.join("&")
      "#{BASE_URL}?#{query_params}"
    end

    def content_type_for_file(file_path)
      case File.extname(file_path).downcase
      when ".mp3"
        "audio/mpeg"
      when ".wav"
        "audio/wav"
      when ".m4a"
        "audio/mp4"
      when ".flac"
        "audio/flac"
      when ".ogg"
        "audio/ogg"
      when ".webm"
        "audio/webm"
      else
        "audio/wav" # Default fallback
      end
    end

    def parse_transcription_response(response)
      handle_response_errors(response)

      data = JSON.parse(response.body.to_s)

      unless data["results"] && data["results"]["channels"]
        raise TranscriptionError, "Invalid response format from Deepgram"
      end

      channel = data["results"]["channels"].first
      alternatives = channel["alternatives"].first

      {
        transcript: alternatives["transcript"],
        confidence: alternatives["confidence"],
        words: extract_words(alternatives["words"] || []),
        utterances: extract_utterances(channel["utterances"] || []),
        paragraphs: extract_paragraphs(alternatives["paragraphs"] || {}),
        metadata: {
          duration: data["metadata"]["duration"],
          channels: data["metadata"]["channels"],
          created: data["metadata"]["created"],
          language_detected: alternatives["detected_language"]
        }
      }
    rescue JSON::ParserError => e
      raise TranscriptionError, "Failed to parse response: #{e.message}"
    end

    def extract_words(words_data)
      words_data.map do |word|
        {
          word: word["word"],
          start: (word["start"] * 1000).to_i, # Convert to milliseconds
          end: (word["end"] * 1000).to_i,
          confidence: word["confidence"],
          punctuated_word: word["punctuated_word"]
        }
      end
    end

    def extract_utterances(utterances_data)
      utterances_data.map do |utterance|
        {
          transcript: utterance["transcript"],
          start: (utterance["start"] * 1000).to_i,
          end: (utterance["end"] * 1000).to_i,
          confidence: utterance["confidence"],
          channel: utterance["channel"],
          speaker: utterance["speaker"]
        }
      end
    end

    def extract_paragraphs(paragraphs_data)
      return [] unless paragraphs_data["paragraphs"]

      paragraphs_data["paragraphs"].map do |paragraph|
        {
          transcript: paragraph["transcript"],
          start: (paragraph["start"] * 1000).to_i,
          end: (paragraph["end"] * 1000).to_i,
          confidence: paragraph["confidence"],
          speaker: paragraph["speaker"]
        }
      end
    end

    def handle_response_errors(response)
      case response.status
      when 200..299
        # Success - continue processing
      when 400
        raise TranscriptionError, "Bad request: #{extract_error_message(response)}"
      when 401
        raise AuthenticationError, "Invalid API key or authentication failed"
      when 403
        raise TranscriptionError, "Forbidden: #{extract_error_message(response)}"
      when 429
        raise RateLimitError, "Rate limit exceeded"
      when 500..599
        raise TranscriptionError, "Deepgram server error (#{response.status})"
      else
        raise TranscriptionError, "Unexpected response status: #{response.status}"
      end
    end

    def extract_error_message(response)
      JSON.parse(response.body.to_s)["message"] rescue response.body.to_s
    end

    def validate_file!(file_path)
      unless File.exist?(file_path)
        raise ArgumentError, "File not found: #{file_path}"
      end

      unless File.readable?(file_path)
        raise ArgumentError, "File not readable: #{file_path}"
      end

      file_size = File.size(file_path)
      max_size = 500 * 1024 * 1024 # 500MB limit

      if file_size > max_size
        raise ArgumentError, "File too large: #{file_size} bytes (max: #{max_size} bytes)"
      end
    end

    def with_retries
      attempts = 0

      begin
        attempts += 1
        yield
      rescue RateLimitError, HTTP::TimeoutError, HTTP::ConnectionError => e
        if attempts < RETRY_ATTEMPTS
          sleep(RETRY_DELAY * attempts)
          retry
        else
          raise TranscriptionError, "Failed after #{RETRY_ATTEMPTS} attempts: #{e.message}"
        end
      end
    end
  end
end
