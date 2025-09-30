module Sessions
  class TrialProcessJob < ApplicationJob
    queue_as :trial_analysis

    retry_on StandardError, wait: :polynomially_longer, attempts: 2
    discard_on ActiveRecord::RecordNotFound

    def perform(trial_session_token)
      @trial_session = TrialSession.find_by!(token: trial_session_token)
      @start_time = Time.current

      Rails.logger.info "Starting trial analysis for session #{trial_session_token}"

      begin
        # Update session state
        @trial_session.update!(
          processing_state: 'processing',
          updated_at: Time.current
        )

        # Extract audio and get duration for time estimates
        media_data = extract_trial_media

        # Update duration for better time estimates
        @trial_session.update!(duration_ms: (media_data[:duration] * 1000).to_i)

        # Process the trial audio with simplified pipeline
        trial_results = process_trial_audio_pipeline(media_data)

        # Store results and mark complete
        @trial_session.update!(
          analysis_data: trial_results,
          processing_state: 'completed',
          completed: true,
          processed_at: Time.current
        )

        Rails.logger.info "Completed trial analysis for session #{trial_session_token} in #{processing_duration}s"

      rescue => e
        handle_trial_error(e)
        raise # Re-raise for job retry logic
      end
    end

    private

    def extract_trial_media
      unless @trial_session.media_files.any?
        raise "No media files attached to trial session"
      end

      media_file = @trial_session.media_files.first
      extractor = Media::Extractor.new(media_file)

      extraction_result = extractor.extract_audio_data

      unless extraction_result[:success]
        raise "Media extraction failed: #{extraction_result[:error]}"
      end

      extraction_result
    end

    def process_trial_audio_pipeline(media_data)
      # Simplified processing pipeline for trial users
      begin
        # Step 1: Transcribe speech (same as full processing)
        transcript_data = transcribe_trial_speech(media_data)

        # Step 2: Basic analysis (no complex AI processing)
        basic_metrics = calculate_trial_metrics(transcript_data)

        Rails.logger.info "Trial processing complete: #{basic_metrics[:word_count]} words, #{basic_metrics[:wpm]} WPM"

        {
          transcript: transcript_data[:transcript],
          wpm: basic_metrics[:wpm],
          filler_count: basic_metrics[:filler_count],
          duration_seconds: basic_metrics[:duration_seconds],
          word_count: basic_metrics[:word_count],
          processed_at: Time.current.iso8601,
          trial_mode: true
        }

      rescue => e
        Rails.logger.error "Trial analysis error: #{e.message}"

        # Return demo data on failure
        {
          transcript: "This is a demo transcription showing basic speech analysis results for trial users.",
          wpm: 150,
          filler_count: 2,
          duration_seconds: 30,
          word_count: 45,
          demo_mode: true,
          error: "Real analysis failed - this is demo data. Sign up for reliable processing!"
        }
      end
    end

    def transcribe_trial_speech(media_data)
      # Use existing STT service but with trial-specific handling
      stt_client = STT::DeepgramClient.new

      transcription_options = {
        language: @trial_session.language,
        model: 'nova', # Use basic model for trials
        punctuate: true,
        diarize: false,
        timestamps: true
      }

      result = stt_client.transcribe_file(
        media_data[:file_path],
        transcription_options
      )

      # Validate minimum transcription quality
      if result[:transcript].blank? || result[:words].blank?
        raise "No speech detected in trial recording"
      end

      if result[:words].length < 3
        raise "Recording too short - please speak for at least 10 seconds"
      end

      result
    end

    def calculate_trial_metrics(transcript_data)
      words = transcript_data[:words] || []
      transcript = transcript_data[:transcript] || ""

      # Basic calculations
      word_count = words.length
      duration_seconds = transcript_data.dig(:metadata, :duration) || 30

      # Calculate WPM
      wpm = duration_seconds > 0 ? (word_count / (duration_seconds / 60.0)).round : 0

      # Count filler words (simple pattern matching)
      filler_words = %w[um uh er ah hmm like you-know so basically actually literally well]
      filler_pattern = /\b(#{filler_words.join('|')})\b/i
      filler_count = transcript.scan(filler_pattern).length

      {
        word_count: word_count,
        duration_seconds: duration_seconds,
        wpm: wpm,
        filler_count: filler_count
      }
    end

    def handle_trial_error(error)
      error_message = case error.class.name
      when 'STT::DeepgramClient::TranscriptionError'
        if error.message.include?("No speech detected")
          "No speech detected in your recording. Please ensure you spoke clearly and try again."
        elsif error.message.include?("too short")
          "Recording too short. Please record for at least 10 seconds."
        else
          "Unable to process your audio. This is a demo - sign up for reliable processing!"
        end
      else
        "Analysis failed. This was just a trial - sign up for full features!"
      end

      Rails.logger.error "Trial processing failed for session #{@trial_session.token}: #{error.message}"

      # Store error state with demo data
      @trial_session.update!(
        processing_state: 'failed',
        analysis_data: {
          error: error_message,
          demo_mode: true,
          transcript: "Demo: This shows how your transcript would appear.",
          wpm: 145,
          filler_count: 1,
          duration_seconds: 30,
          word_count: 42
        }
      )
    end

    def processing_duration
      Time.current - @start_time
    end
  end
end