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
        # Update session state and record when processing started
        @trial_session.update!(
          processing_state: "processing",
          updated_at: Time.current,
          processing_started_at: Time.current
        )

        # Extract audio and get duration for time estimates
        media_data = extract_trial_media

        # Update duration for better time estimates
        @trial_session.update!(duration_ms: (media_data[:duration] * 1000).to_i)

        # Phase 1: Quick analysis with rule-based metrics (15-20 seconds)
        quick_results = process_phase_1_quick_analysis(media_data)

        # Store quick results and mark as preview ready
        @trial_session.update!(
          analysis_data: quick_results,
          processing_state: "preview_ready"
        )

        Rails.logger.info "Phase 1 complete for session #{trial_session_token} - preview ready in #{processing_duration}s"

        # Phase 2: Full AI analysis (continues in background)
        enhanced_results = process_phase_2_ai_analysis(quick_results, media_data)

        # Store enhanced results and mark complete
        @trial_session.update!(
          analysis_data: enhanced_results,
          processing_state: "completed",
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

    def process_phase_1_quick_analysis(media_data)
      # Phase 1: Fast transcription + rule-based comprehensive metrics
      begin
        # Step 1: Transcribe speech
        transcript_data = transcribe_trial_speech(media_data)

        # Step 2: Calculate comprehensive metrics (without AI)
        metrics_calculator = Analysis::Metrics.new(
          transcript_data,
          [], # No issues yet (AI will detect them)
          {
            language: @trial_session.language,
            ai_detected_fillers: [] # Use regex fallback for now
          }
        )

        comprehensive_metrics = metrics_calculator.calculate_all_metrics

        Rails.logger.info "Phase 1 complete: #{transcript_data[:words].length} words, #{comprehensive_metrics.dig(:speaking_metrics, :words_per_minute)} WPM"

        # Store both basic and comprehensive data
        {
          transcript: transcript_data[:transcript],
          words: transcript_data[:words],
          metadata: transcript_data[:metadata],
          wpm: comprehensive_metrics.dig(:speaking_metrics, :words_per_minute),
          filler_count: comprehensive_metrics.dig(:clarity_metrics, :filler_metrics, :total_filler_count),
          duration_seconds: comprehensive_metrics.dig(:basic_metrics, :duration_seconds),
          word_count: comprehensive_metrics.dig(:basic_metrics, :word_count),
          comprehensive_metrics: comprehensive_metrics,
          processed_at: Time.current.iso8601,
          trial_mode: true,
          phase: "quick_preview"
        }

      rescue => e
        Rails.logger.error "Phase 1 analysis error: #{e.message}"
        raise # Let error handler deal with it
      end
    end

    def process_phase_2_ai_analysis(quick_results, media_data)
      # Phase 2: Enhance with AI analysis
      begin
        @trial_session.update!(processing_state: "ai_analyzing")

        transcript_data = {
          transcript: quick_results[:transcript],
          words: quick_results[:words],
          metadata: quick_results[:metadata]
        }

        # Run AI-powered filler detection
        ai_refiner = Analysis::AiRefiner.new(
          transcript_data,
          @trial_session.language
        )

        ai_results = ai_refiner.refine_analysis

        # Recalculate metrics with AI-detected fillers
        metrics_calculator = Analysis::Metrics.new(
          transcript_data,
          ai_results[:issues] || [],
          {
            language: @trial_session.language,
            ai_detected_fillers: ai_results[:ai_detected_fillers] || []
          }
        )

        enhanced_metrics = metrics_calculator.calculate_all_metrics

        Rails.logger.info "Phase 2 complete: AI detected #{ai_results[:ai_detected_fillers]&.length || 0} fillers"

        # Merge quick results with AI-enhanced metrics
        quick_results.merge(
          comprehensive_metrics: enhanced_metrics,
          ai_insights: ai_results[:insights],
          micro_tips: ai_results[:micro_tips],
          filler_count: enhanced_metrics.dig(:clarity_metrics, :filler_metrics, :total_filler_count),
          wpm: enhanced_metrics.dig(:speaking_metrics, :words_per_minute),
          phase: "ai_enhanced"
        )

      rescue => e
        Rails.logger.error "Phase 2 AI analysis error: #{e.message}"
        # Return quick results without AI enhancement
        Rails.logger.warn "Falling back to Phase 1 results without AI enhancement"
        quick_results.merge(phase: "ai_failed", ai_error: e.message)
      end
    end

    def transcribe_trial_speech(media_data)
      # Use existing STT service but with trial-specific handling
      stt_client = Stt::DeepgramClient.new

      transcription_options = {
        language: @trial_session.language,
        model: "nova", # Use basic model for trials
        punctuate: true,
        diarize: false,
        timestamps: true
      }

      result = stt_client.transcribe_file(
        media_data[:audio_file_path],
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


    def handle_trial_error(error)
      error_message = case error.class.name
      when "Stt::DeepgramClient::TranscriptionError"
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
        processing_state: "failed",
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
