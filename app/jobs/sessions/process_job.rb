module Sessions
  class ProcessJob < ApplicationJob
    queue_as :speech_analysis

    retry_on StandardError, wait: :polynomially_longer, attempts: 3
    discard_on ActiveRecord::RecordNotFound

    # Custom error classes
    class ProcessingError < StandardError; end
    class MediaExtractionError < ProcessingError; end
    class TranscriptionError < ProcessingError; end
    class AnalysisError < ProcessingError; end

    def perform(session_id, options = {})
      @options = options.with_indifferent_access

      # Determine if this is a trial session or regular session
      if @options[:is_trial]
        @session = TrialSession.find(session_id)
        Rails.logger.info "Starting speech analysis for TRIAL session #{session_id} - Job execution confirmed"
      else
        @session = Session.find(session_id)
        Rails.logger.info "Starting speech analysis for session #{session_id} - Job execution confirmed"
      end

      @start_time = Time.current

      begin
        # Update session state and record job execution time
        update_session_state("processing", nil)
        @session.update!(
          updated_at: Time.current,
          processing_started_at: Time.current
        ) # Heartbeat for monitoring

        # Execute the analysis pipeline
        @pipeline_result = execute_analysis_pipeline

        # Store results and update session
        finalize_session(@pipeline_result)

        Rails.logger.info "Completed speech analysis for session #{session_id} in #{processing_duration}s"

      rescue => e
        handle_processing_error(e)
        raise # Re-raise for job retry logic
      end
    end

    private

    def execute_analysis_pipeline
      pipeline_result = {
        media_extraction: nil,
        transcription: nil,
        rule_analysis: nil,
        ai_refinement: nil,
        metrics: nil,
        embeddings: nil,
        processing_metadata: {
          started_at: @start_time,
          pipeline_version: "1.0",
          options: @options
        }
      }

      # Step 1: Extract audio from media files
      Rails.logger.info "Step 1: Extracting media for session #{@session.id}"
      update_processing_stage("extraction", 15)
      media_data = extract_media
      pipeline_result[:media_extraction] = media_data

      # Store initial metrics after extraction
      store_interim_metrics({
        duration_seconds: media_data[:duration]
      })

      # Step 2: Transcribe speech to text
      Rails.logger.info "Step 2: Transcribing speech for session #{@session.id}"
      update_processing_stage("transcription", 35)
      transcript_data = transcribe_speech(media_data)
      pipeline_result[:transcription] = transcript_data

      # Store metrics after transcription
      store_interim_metrics({
        duration_seconds: media_data[:duration],
        word_count: transcript_data[:words]&.length || 0,
        estimated_wpm: calculate_quick_wpm(transcript_data, media_data[:duration])
      })

      # Step 3: Check context relevance (early fail-fast for off-topic responses)
      Rails.logger.info "Step 3: Checking context relevance for session #{@session.id}"
      update_processing_stage("relevance", 45)
      relevance_result = check_context_relevance(transcript_data)
      pipeline_result[:relevance_check] = relevance_result

      # If off-topic and first attempt, stop processing and prompt user to retake
      if relevance_result[:off_topic] && @session.retake_count == 0
        Rails.logger.info "Session #{@session.id} flagged as off-topic (first attempt) - stopping for retake"
        handle_off_topic_response(relevance_result, pipeline_result)
        return pipeline_result # Stop processing here
      end

      # If off-topic on second attempt, apply penalty and continue
      if relevance_result[:off_topic] && @session.retake_count >= 1
        Rails.logger.info "Session #{@session.id} still off-topic on attempt #{@session.retake_count + 1} - applying penalty"
        @relevance_penalty = 10 # Will be applied in metrics calculation
      end

      # Step 4: Run rule-based analysis
      Rails.logger.info "Step 4: Running rule-based analysis for session #{@session.id}"
      update_processing_stage("analysis", 60)
      rule_issues = analyze_with_rules(transcript_data)
      pipeline_result[:rule_analysis] = {
        issues: rule_issues,
        issue_count: rule_issues.length
      }

      # Store metrics after rule-based analysis
      filler_issues = rule_issues.select { |i| i[:kind] == "filler_word" }
      store_interim_metrics({
        duration_seconds: media_data[:duration],
        word_count: transcript_data[:words]&.length || 0,
        estimated_wpm: calculate_quick_wpm(transcript_data, media_data[:duration]),
        filler_word_count: filler_issues.length,
        pause_count: rule_issues.select { |i| i[:kind] == "long_pause" }.length
      })

      # Step 5: AI refinement and enhancement (OPTIMIZED: unified analysis)
      if should_run_ai_analysis?
        Rails.logger.info "Step 5: Running comprehensive AI analysis for session #{@session.id} (optimized)"
        update_processing_stage("refinement", 80)
        ai_results = refine_with_ai(transcript_data, rule_issues)
        pipeline_result[:ai_refinement] = ai_results
      else
        Rails.logger.info "Step 5: Skipping AI analysis (disabled or insufficient data)"
        pipeline_result[:ai_refinement] = { skipped: true, reason: skip_ai_reason }
      end

      # Step 6: Calculate comprehensive metrics
      Rails.logger.info "Step 6: Calculating metrics for session #{@session.id}"
      final_issues = pipeline_result.dig(:ai_refinement, :refined_issues) || rule_issues
      metrics_data = calculate_comprehensive_metrics(transcript_data, final_issues, media_data)

      # Apply relevance penalty if applicable (second off-topic attempt)
      if @relevance_penalty && metrics_data.dig(:overall_scores, :overall_score)
        original_score = metrics_data[:overall_scores][:overall_score]
        penalized_score = [ original_score - @relevance_penalty, 0 ].max
        metrics_data[:overall_scores][:overall_score] = penalized_score
        metrics_data[:overall_scores][:relevance_penalty_applied] = @relevance_penalty
        Rails.logger.info "Applied relevance penalty: #{original_score} -> #{penalized_score}"
      end

      pipeline_result[:metrics] = metrics_data

      # Step 7: Generate embeddings for future personalization
      if should_generate_embeddings?
        Rails.logger.info "Step 7: Generating embeddings for session #{@session.id}"
        embeddings_data = generate_session_embeddings(transcript_data, final_issues)
        pipeline_result[:embeddings] = embeddings_data
      else
        Rails.logger.info "Step 7: Skipping embedding generation"
        pipeline_result[:embeddings] = { skipped: true }
      end

      # Update processing metadata
      pipeline_result[:processing_metadata][:completed_at] = Time.current
      pipeline_result[:processing_metadata][:total_duration_seconds] = processing_duration

      pipeline_result
    end

    def check_context_relevance(transcript_data)
      # Skip relevance check if no title/prompt provided
      return { on_topic: true, relevance_score: 1.0, skipped: true } if @session.title.blank?

      # Skip relevance check if off_topic was already set to false (user chose "Continue Anyway")
      return { on_topic: true, relevance_score: 1.0, skipped: true, reason: "user_override" } if @session.off_topic == false && @session.processing_state == "pending"

      begin
        relevance_checker = Analysis::RelevanceChecker.new(@session)
        result = relevance_checker.check_relevance(transcript_data)

        # Store relevance data in session
        @session.update!(
          relevance_score: result[:relevance_score],
          relevance_feedback: result[:feedback],
          off_topic: !result[:on_topic]
        )

        result
      rescue => e
        Rails.logger.error "Relevance check failed for session #{@session.id}: #{e.message}"
        # On error, assume on-topic to avoid blocking user
        { on_topic: true, relevance_score: 1.0, error: e.message }
      end
    end

    def handle_off_topic_response(relevance_result, pipeline_result)
      # Store partial analysis data for user to review
      analysis_data = {
        transcript: pipeline_result.dig(:transcription, :transcript),
        processing_state: "relevance_failed",
        relevance_score: relevance_result[:relevance_score],
        relevance_feedback: relevance_result[:feedback],
        duration_seconds: pipeline_result.dig(:media_extraction, :duration),
        word_count: pipeline_result.dig(:transcription, :words)&.length || 0
      }

      @session.update!(
        analysis_data: analysis_data,
        processing_state: "relevance_failed",
        completed: false
      )

      Rails.logger.info "Session #{@session.id} stopped for relevance retake"
    end

    def extract_media
      unless @session.media_files.any?
        raise MediaExtractionError, "No media files attached to session"
      end

      media_file = @session.media_files.first
      extractor = Media::Extractor.new(media_file)

      extraction_result = extractor.extract_audio_data

      unless extraction_result[:success]
        raise MediaExtractionError, "Media extraction failed: #{extraction_result[:error]}"
      end

      {
        file_path: extraction_result[:audio_file_path],
        duration: extraction_result[:duration],
        format: extraction_result[:format],
        sample_rate: extraction_result[:sample_rate],
        file_size: extraction_result[:file_size],
        extraction_metadata: extraction_result[:metadata],
        temp_file_ref: extraction_result[:temp_file] # Keep temp file alive during processing
      }
    end

    def transcribe_speech(media_data)
      stt_client = Stt::DeepgramClient.new

      transcription_options = {
        language: @session.language,
        model: determine_transcription_model,
        punctuate: true,
        diarize: false, # Single speaker for now
        timestamps: true,
        utterances: true
      }.merge(@options[:transcription_options] || {})

      transcription_result = stt_client.transcribe_file(
        media_data[:file_path],
        transcription_options
      )

      # Validate transcription quality
      validate_transcription_quality(transcription_result)

      # Store transcript immediately after successful transcription
      # Merge into existing data to preserve processing_stage and processing_progress
      current_data = @session.analysis_data || {}
      current_data["transcript"] = transcription_result[:transcript]
      @session.update!(analysis_data: current_data)

      transcription_result
    end

    def analyze_with_rules(transcript_data)
      rule_detector = Analysis::RuleDetector.new(
        transcript_data,
        language: @session.language,
        user: @session.user
      )

      begin
        if rule_detector.rules_available?
          detected_issues = rule_detector.detect_all_issues

          # Store issues in database
          store_detected_issues(detected_issues, "rule")

          Rails.logger.info "Detected #{detected_issues.length} rule-based issues for language '#{@session.language}'"
        else
          detected_issues = []
          Rails.logger.info "No rules available for language '#{@session.language}', proceeding with AI-only analysis"
        end

        detected_issues

      rescue => e
        raise AnalysisError, "Rule-based analysis failed: #{e.message}"
      end
    end

    def refine_with_ai(transcript_data, rule_issues)
      ai_refiner = Analysis::AiRefiner.new(@session, @options[:ai_options] || {})

      begin
        refinement_result = ai_refiner.refine_analysis(transcript_data, rule_issues)

        # Store refined issues (replacing rule-based ones)
        if refinement_result[:refined_issues].any?
          # Clear existing issues and store refined ones
          @session.issues.destroy_all
          store_detected_issues(refinement_result[:refined_issues], "ai_refined")
        end

        Rails.logger.info "AI refinement completed using unified analysis (#{refinement_result[:metadata][:optimization]})"
        refinement_result

      rescue => e
        Rails.logger.error "AI refinement failed, continuing with rule-based results: #{e.message}"
        # Return fallback results
        {
          refined_issues: rule_issues,
          fallback_mode: true,
          error: e.message
        }
      end
    end

    def calculate_comprehensive_metrics(transcript_data, issues, media_data)
      # Extract AI-detected filler words from issues for metrics calculation
      ai_detected_fillers = issues.select { |i| i[:kind] == "filler_word" && i[:source] == "ai" }

      # Calculate amplitude variation data for inflection analysis
      amplitude_data = []
      if media_data && media_data[:file_path]
        begin
          Rails.logger.info "Calculating amplitude variation for inflection analysis"
          extractor = Media::Extractor.new(media_data[:file_path])
          amplitude_data = extractor.calculate_amplitude_variation_per_word(transcript_data[:words] || [])
          Rails.logger.info "Calculated amplitude data for #{amplitude_data.length} words"
        rescue => e
          Rails.logger.warn "Amplitude calculation failed, continuing without inflection data: #{e.message}"
          # Continue without amplitude data - inflection will fall back to punctuation only
        end
      end

      metrics_calculator = Analysis::Metrics.new(
        transcript_data,
        issues,
        language: @session.language,
        ai_detected_fillers: ai_detected_fillers,
        audio_file: media_data&.[](:file_path),
        amplitude_data: amplitude_data,
        user: @session.user
      )

      begin
        metrics_data = metrics_calculator.calculate_all_metrics
        Rails.logger.info "Calculated comprehensive metrics: overall score #{metrics_data.dig(:overall_scores, :overall_score)}"
        metrics_data
      rescue => e
        Rails.logger.error "Metrics calculation failed: #{e.message}"
        # Return basic metrics as fallback
        {
          error: e.message,
          basic_metrics: {
            word_count: transcript_data[:words]&.length || 0,
            duration_ms: (transcript_data.dig(:metadata, :duration) || 0) * 1000
          }
        }
      end
    end

    def generate_session_embeddings(transcript_data, issues)
      return { skipped: true, reason: "Embeddings disabled" } unless embedding_service_available?

      begin
        embeddings_service = Ai::Embeddings.new(
          model: @options.dig(:embeddings, :model) || "text-embedding-3-small"
        )

        # Temporarily store key data in session for embedding generation
        @session.update!(analysis_data: @session.analysis_data.merge({
          "transcript" => transcript_data[:transcript],
          "key_segments" => extract_key_segments(transcript_data, issues)
        }))

        embeddings_data = embeddings_service.generate_session_embeddings(@session)

        # Store embeddings in database
        embeddings_service.store_session_embeddings(@session, embeddings_data)

        Rails.logger.info "Generated embeddings: #{embeddings_data[:metadata][:total_vectors]} vectors"
        embeddings_data

      rescue => e
        Rails.logger.error "Embeddings generation failed: #{e.message}"
        { error: e.message, skipped: true }
      end
    end

    def store_detected_issues(issues, source_type)
      issues.each do |issue_data|
        issue_attributes = {
          session: @session,
          kind: issue_data[:kind],
          start_ms: issue_data[:start_ms],
          end_ms: issue_data[:end_ms],
          text: issue_data[:text],
          source: map_source_type(source_type),
          rationale: issue_data[:rationale],
          tip: issue_data[:tip],
          severity: issue_data[:severity],
          category: issue_data[:category]
        }

        # Store filler_word data in coaching_note for AI-detected filler words
        if issue_data[:kind] == "filler_word" && issue_data[:filler_word].present?
          issue_attributes[:coaching_note] = issue_data[:filler_word]
        end

        Issue.create!(issue_attributes)
      end
    end

    def finalize_session(pipeline_result)
      # Check duration compliance for enforced sessions
      validate_minimum_duration_compliance(pipeline_result)

      # Extract metrics for easier UI access
      metrics = pipeline_result[:metrics] || {}
      speaking_metrics = metrics[:speaking_metrics] || {}
      clarity_metrics = metrics[:clarity_metrics] || {}
      fluency_metrics = metrics[:fluency_metrics] || {}
      engagement_metrics = metrics[:engagement_metrics] || {}
      overall_scores = metrics[:overall_scores] || {}
      basic_metrics = metrics[:basic_metrics] || {}

      # Generate coaching insights and micro-tips (Phase 2)
      coaching_insights = {}
      micro_tips = []

      begin
        Rails.logger.info "Generating coaching insights and micro-tips for session #{@session.id}"

        # Extract coaching insights from metrics
        final_issues = pipeline_result.dig(:ai_refinement, :refined_issues) || pipeline_result.dig(:rule_analysis, :issues) || []
        ai_detected_fillers = final_issues.select { |i| i[:kind] == "filler_word" && i[:source] == "ai" }

        # Calculate amplitude data for insights (reuse if already calculated)
        amplitude_data = []
        media_data = pipeline_result[:media_extraction]
        if media_data && media_data[:file_path]
          begin
            extractor = Media::Extractor.new(media_data[:file_path])
            amplitude_data = extractor.calculate_amplitude_variation_per_word(pipeline_result[:transcription][:words] || [])
          rescue => e
            Rails.logger.warn "Amplitude calculation for insights failed: #{e.message}"
          end
        end

        metrics_calculator = Analysis::Metrics.new(
          pipeline_result[:transcription],
          final_issues,
          language: @session.language,
          ai_detected_fillers: ai_detected_fillers,
          audio_file: media_data&.[](:file_path),
          amplitude_data: amplitude_data,
          user: @session.user
        )
        coaching_insights = metrics_calculator.extract_coaching_insights

        # Generate micro-tips (will be empty for first session, which is fine)
        # Focus areas are determined later in the controller, so we pass empty array for now
        tip_generator = Analysis::MicroTipGenerator.new(
          metrics,
          coaching_insights,
          [] # Focus areas - will be filtered out later
        )
        micro_tips = tip_generator.generate_tips

        Rails.logger.info "Generated #{micro_tips.length} micro-tips for session #{@session.id}"
      rescue => e
        Rails.logger.error "Failed to generate micro-tips for session #{@session.id}: #{e.message}"
        # Continue without tips - not a critical failure
      end

      # Build streamlined analysis data - store complete metrics, use accessors for flat data
      analysis_data = {
        # Core data
        transcript: pipeline_result.dig(:transcription, :transcript),
        processing_state: "completed",

        # Essential flat metrics for UI compatibility
        wpm: speaking_metrics[:words_per_minute],
        filler_rate: clarity_metrics.dig(:filler_metrics, :filler_rate_decimal), # Already stored as decimal (0.01 = 1%)
        clarity_score: clarity_metrics[:clarity_score] || 0, # Already stored as decimal (0.85 = 85%)
        fluency_score: fluency_metrics[:fluency_score] || 0, # Already stored as decimal
        engagement_score: engagement_metrics[:engagement_score] || 0, # Already stored as decimal
        pace_consistency: speaking_metrics[:pace_consistency] || 0, # Already stored as decimal
        overall_score: overall_scores[:overall_score] || 0, # Already stored as decimal

        # Timing essentials
        duration_seconds: basic_metrics[:duration_seconds],
        speaking_time_ms: basic_metrics[:speaking_time_ms],
        pause_time_ms: basic_metrics[:pause_time_ms],

        # Key pause metrics
        average_pause_ms: clarity_metrics.dig(:pause_metrics, :average_pause_ms),
        longest_pause_ms: clarity_metrics.dig(:pause_metrics, :longest_pause_ms),
        long_pause_count: clarity_metrics.dig(:pause_metrics, :long_pause_count),
        pause_quality_score: clarity_metrics.dig(:pause_metrics, :pause_quality_score),

        # Assessment results
        grade: overall_scores[:grade],
        component_scores: overall_scores[:component_scores],
        strengths: overall_scores[:strengths],
        areas_for_improvement: overall_scores[:areas_for_improvement],

        # Complete structured data for advanced features
        metrics: pipeline_result[:metrics],
        pipeline_metadata: pipeline_result[:processing_metadata],
        ai_insights: pipeline_result.dig(:ai_refinement, :ai_insights) || [],
        coaching_recommendations: pipeline_result.dig(:ai_refinement, :coaching_recommendations) || {}
      }

      # Update session with final results including micro-tips
      @session.update!(
        analysis_data: analysis_data,
        micro_tips: micro_tips,
        coaching_insights: coaching_insights,
        processing_state: "completed",
        completed: true,
        processed_at: Time.current
      )

      Rails.logger.info "Session #{@session.id} finalized successfully"

      # Extend trial if user practiced with 1+ minute session
      extend_trial_if_qualified

      # Clean up temporary files
      cleanup_temp_files(pipeline_result)
    end

    def handle_processing_error(error)
      # Generate user-friendly error message based on the specific error type and API status
      user_friendly_message = case error
      when MediaExtractionError, Media::Extractor::ExtractionError
        Rails.logger.error "Media extraction failed for session #{@session.id}: #{error.message}"
        if error.message.include?("too short") || error.message.include?("file is too short")
          "Your recording is too short. Please record at least 1 second of audio."
        elsif error.message.include?("Empty file") || error.message.include?("appears to be empty")
          "The uploaded file appears to be empty. Please try recording again."
        elsif error.message.include?("Invalid or corrupted") || error.message.include?("corrupted")
          "The audio file appears to be corrupted. Please try recording again."
        elsif error.message.include?("no audio content")
          "The uploaded file doesn't contain any detectable audio. Please ensure you spoke during recording and try again."
        else
          "There was an issue with your audio file. Please try recording again."
        end
      when Stt::DeepgramClient::TranscriptionError, TranscriptionError
        Rails.logger.error "Transcription failed for session #{@session.id}: #{error.message}"
        if error.message.include?("Rate limit")
          "Transcription service is busy. Please try again in a few moments."
        elsif error.message.include?("Invalid API key")
          "Speech recognition service is temporarily unavailable. Please try again later."
        elsif error.message.include?("No speech detected")
          error.message # Use the detailed message we crafted
        elsif error.message.include?("too short or unclear")
          error.message # Use the detailed message we crafted
        elsif error.message.include?("too quiet or unclear")
          error.message # Use the detailed message we crafted
        else
          "Unable to transcribe your speech. Please ensure you spoke clearly and try again."
        end
      when Ai::Client::ClientError, Ai::Client::RateLimitError, Ai::Client::AuthenticationError
        Rails.logger.error "AI service error for session #{@session.id}: #{error.class} - #{error.message}"
        if error.message.include?("503") || error.message.include?("Service Unavailable")
          "AI analysis service is temporarily unavailable. Your speech was transcribed successfully - please try reprocessing in a few minutes."
        elsif error.message.include?("Rate limit") || error.is_a?(Ai::Client::RateLimitError)
          "AI service is busy. Please try reprocessing in a few moments."
        elsif error.message.include?("quota") || error.is_a?(Ai::Client::QuotaExceededError)
          "AI analysis is temporarily limited. Your basic speech analysis is complete."
        else
          "AI enhancement is temporarily unavailable. Your basic speech analysis is complete."
        end
      when AnalysisError
        Rails.logger.error "Analysis failed for session #{@session.id}: #{error.message}"
        "There was an issue analyzing your speech. Please try again."
      else
        Rails.logger.error "Unexpected error for session #{@session.id}: #{error.class} - #{error.message}"
        "An unexpected error occurred during analysis. Please try again."
      end

      error_details = {
        error_class: error.class.name,
        error_message: error.message,
        user_message: user_friendly_message,
        backtrace: error.backtrace&.first(10),
        occurred_at: Time.current.iso8601,
        processing_duration: processing_duration,
        session_id: @session.id,
        session_language: @session.language,
        pipeline_stage: determine_failed_stage(error)
      }

      Rails.logger.error "Session processing failed for session #{@session.id}: #{error.message}"
      Rails.logger.error error.backtrace&.first(5)&.join("\n")

      # Report to monitoring system with detailed context
      Monitoring::ErrorReporter.report_service_error(self, error, error_details)

      # Update session with error state and user-friendly message
      update_session_state("failed", user_friendly_message)

      # Clean up any temp files even on error
      cleanup_temp_files(@pipeline_result) if defined?(@pipeline_result)
    end

    def update_session_state(state, error_message = nil)
      updates = {
        processing_state: state,
        incomplete_reason: error_message
      }

      updates[:completed] = false if state == "failed"
      updates[:processed_at] = Time.current if state.in?(%w[completed failed])

      @session.update!(updates)
    end

    # Helper methods for decision making

    def should_run_ai_analysis?
      return false if @options[:skip_ai] == true
      return false unless ai_service_available?

      # Check if session has enough content for AI analysis
      return false unless sufficient_content_for_ai?

      # Check user's AI quota/preferences
      return false unless user_has_ai_quota?

      true
    end

    def should_generate_embeddings?
      return false if @options[:skip_embeddings] == true
      return false unless embedding_service_available?

      # Only generate embeddings if session was successful
      @session.processing_state != "failed"
    end

    def ai_service_available?
      ENV["OPENAI_API_KEY"].present?
    end

    def embedding_service_available?
      ai_service_available? # Same requirement for now
    end

    def sufficient_content_for_ai?
      return false unless @session.analysis_data["transcript"].present?

      transcript = @session.analysis_data["transcript"]
      word_count = transcript.split.length

      word_count >= 50 # Minimum 50 words for meaningful AI analysis
    end

    def user_has_ai_quota?
      # Placeholder for quota checking logic
      # Could check subscription status, daily limits, etc.
      true
    end

    # Extend trial for users who practice with 1+ minute sessions
    # Uses calendar day logic: session on day X = free access through end of day X+1
    def extend_trial_if_qualified
      user = @session.user
      return unless user
      return unless user.subscription_free_trial?

      # Attempt to extend trial based on this session
      if user.extend_trial_for_practice!(@session)
        Rails.logger.info "Trial extended for user #{user.id} until #{user.trial_expires_at} (session #{@session.id})"
      end
    rescue => e
      Rails.logger.error "Failed to extend trial for user #{user.id}: #{e.message}"
    end

    def skip_ai_reason
      return "disabled_by_option" if @options[:skip_ai]
      return "api_key_missing" unless ai_service_available?
      return "insufficient_content" unless sufficient_content_for_ai?
      return "quota_exceeded" unless user_has_ai_quota?
      "unknown"
    end

    def determine_transcription_model
      # Use model from environment variable, with fallback based on language
      default_model = ENV["DEEPGRAM_MODEL"] || "nova-3"

      # Could be enhanced with user preferences or content analysis
      default_model
    end

    def validate_transcription_quality(transcript_data)
      # Basic validation
      unless transcript_data[:transcript].present?
        raise TranscriptionError, "No speech detected in the recording. Please ensure you spoke clearly and check your microphone settings."
      end

      unless transcript_data[:words].present?
        raise TranscriptionError, "No word-level timing data received. The audio may be too quiet or unclear."
      end

      # Check minimum quality thresholds
      word_count = transcript_data[:words].length
      if word_count < 2
        raise TranscriptionError, "Recording too short or unclear. Please speak for at least a few seconds with clear audio."
      elsif word_count < 5
        Rails.logger.warn "Very short transcription (#{word_count} words) - results may be inaccurate"
      end

      # Check for timing data quality
      words_with_timing = transcript_data[:words].count { |w| w[:start] && w[:end] }
      timing_ratio = words_with_timing.to_f / word_count

      if timing_ratio < 0.8
        Rails.logger.warn "Poor timing data quality (#{(timing_ratio * 100).round}% coverage)"
      end
    end

    def extract_key_segments(transcript_data, issues)
      # Extract segments that are interesting for embedding generation
      segments = []

      # Add segments around high-priority issues
      high_priority_issues = issues.select { |i| i[:severity] == "high" }
      high_priority_issues.first(3).each do |issue|
        segments << {
          type: "issue_context",
          start_ms: issue[:start_ms],
          end_ms: issue[:end_ms],
          text: issue[:text],
          issue_kind: issue[:kind]
        }
      end

      # Add a middle segment for general content
      if transcript_data[:words]&.length > 20
        words = transcript_data[:words]
        mid_point = words.length / 2
        segment_words = words[(mid_point - 10)..(mid_point + 10)]

        if segment_words.any?
          segments << {
            type: "representative_sample",
            start_ms: segment_words.first[:start],
            end_ms: segment_words.last[:end],
            text: segment_words.map { |w| w[:word] }.join(" ")
          }
        end
      end

      segments
    end

    def map_source_type(source_type)
      case source_type
      when "rule" then "rule"
      when "ai_refined" then "ai"
      else "rule"
      end
    end

    def extract_issue_metadata(issue_data)
      metadata = {}

      # Store additional AI-specific metadata
      if issue_data[:ai_confidence]
        metadata[:ai_confidence] = issue_data[:ai_confidence]
        metadata[:validation_status] = issue_data[:validation_status]
      end

      # Store pattern matching info
      if issue_data[:matched_words]
        metadata[:matched_words] = issue_data[:matched_words]
      end

      # Store timing and context info
      if issue_data[:duration_ms]
        metadata[:duration_ms] = issue_data[:duration_ms]
      end

      metadata.present? ? metadata : nil
    end

    def processing_duration
      Time.current - @start_time
    end

    def determine_failed_stage(error)
      case error
      when MediaExtractionError
        "media_extraction"
      when TranscriptionError
        "transcription"
      when AnalysisError
        "analysis"
      when Ai::Client::ClientError, Ai::Client::RateLimitError, Ai::Client::AuthenticationError
        "ai_processing"
      else
        "unknown"
      end
    end

    def validate_minimum_duration_compliance(pipeline_result)
      return unless @session.minimum_duration_enforced?
      return unless @session.target_seconds.present?

      # Get actual duration from the processed audio
      actual_duration_seconds = pipeline_result.dig(:metrics, :basic_metrics, :duration_seconds) ||
                               pipeline_result.dig(:media_extraction, :duration) || 0

      target_duration_seconds = @session.target_seconds

      # Check if session meets minimum duration requirement (allow 5 second tolerance)
      if actual_duration_seconds < (target_duration_seconds - 5)
        shortfall_seconds = target_duration_seconds - actual_duration_seconds

        Rails.logger.warn "Session #{@session.id} incomplete: #{actual_duration_seconds}s vs required #{target_duration_seconds}s"

        # Mark session as incomplete with specific reason
        @session.update!(
          completed: false,
          incomplete_reason: "Session stopped early. Recorded #{actual_duration_seconds.round}s of #{target_duration_seconds}s required (#{shortfall_seconds.round}s short)."
        )

        # Still allow processing to complete so user gets partial feedback
        Rails.logger.info "Continuing analysis for incomplete session #{@session.id} to provide partial feedback"
      else
        Rails.logger.info "Session #{@session.id} meets duration requirement: #{actual_duration_seconds}s >= #{target_duration_seconds}s"
      end
    end

    def cleanup_temp_files(pipeline_result)
      return unless pipeline_result&.dig(:media_extraction, :temp_file_ref)

      begin
        temp_file = pipeline_result[:media_extraction][:temp_file_ref]
        if temp_file.respond_to?(:close!) && temp_file.respond_to?(:unlink)
          temp_file.close!
          temp_file.unlink if temp_file.path && File.exist?(temp_file.path)
          Rails.logger.info "Cleaned up temporary file for session #{@session.id}"
        end
      rescue => e
        Rails.logger.warn "Failed to cleanup temp file for session #{@session.id}: #{e.message}"
      end
    end

    # Progressive metrics helpers
    def update_processing_stage(stage, progress_percent)
      # Store current stage and progress in session for API to fetch
      current_data = @session.analysis_data || {}
      current_data["processing_stage"] = stage
      current_data["processing_progress"] = progress_percent
      # Use update! to touch updated_at so polling can see changes
      @session.update!(analysis_data: current_data)

      # Optional: Add delay in development to make progress visible
      # Set SLOW_PROCESSING=true to see incremental progress updates
      if Rails.env.development? && ENV["SLOW_PROCESSING"] == "true"
        sleep(2)
        Rails.logger.debug "Progress update: #{stage} at #{progress_percent}%"
      end
    end

    def store_interim_metrics(metrics)
      # Store interim metrics that can be displayed during processing
      current_data = @session.analysis_data || {}
      current_data["interim_metrics"] = metrics
      @session.update_column(:analysis_data, current_data)
      Rails.logger.info "Stored interim metrics for session #{@session.id}: #{metrics.inspect}"
    end

    def calculate_quick_wpm(transcript_data, duration_seconds)
      return 0 if transcript_data[:words].blank? || duration_seconds.to_f <= 0

      word_count = transcript_data[:words].length
      duration_minutes = duration_seconds.to_f / 60.0
      (word_count / duration_minutes).round
    end
  end
end
