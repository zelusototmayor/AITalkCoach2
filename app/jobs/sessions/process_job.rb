module Sessions
  class ProcessJob < ApplicationJob
    queue_as :speech_analysis
    
    retry_on StandardError, wait: :exponentially_longer, attempts: 3
    discard_on ActiveRecord::RecordNotFound
    
    # Custom error classes
    class ProcessingError < StandardError; end
    class MediaExtractionError < ProcessingError; end
    class TranscriptionError < ProcessingError; end
    class AnalysisError < ProcessingError; end
    
    def perform(session_id, options = {})
      @session = Session.find(session_id)
      @options = options.with_indifferent_access
      @start_time = Time.current
      
      Rails.logger.info "Starting speech analysis for session #{session_id}"
      
      begin
        # Update session state
        update_session_state('processing', nil)
        
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
          pipeline_version: '1.0',
          options: @options
        }
      }
      
      # Step 1: Extract audio from media files
      Rails.logger.info "Step 1: Extracting media for session #{@session.id}"
      media_data = extract_media
      pipeline_result[:media_extraction] = media_data
      
      # Step 2: Transcribe speech to text
      Rails.logger.info "Step 2: Transcribing speech for session #{@session.id}"
      transcript_data = transcribe_speech(media_data)
      pipeline_result[:transcription] = transcript_data
      
      # Step 3: Run rule-based analysis
      Rails.logger.info "Step 3: Running rule-based analysis for session #{@session.id}"
      rule_issues = analyze_with_rules(transcript_data)
      pipeline_result[:rule_analysis] = {
        issues: rule_issues,
        issue_count: rule_issues.length
      }
      
      # Step 4: AI refinement and enhancement
      if should_run_ai_analysis?
        Rails.logger.info "Step 4: Running AI refinement for session #{@session.id}"
        ai_results = refine_with_ai(transcript_data, rule_issues)
        pipeline_result[:ai_refinement] = ai_results
      else
        Rails.logger.info "Step 4: Skipping AI analysis (disabled or insufficient data)"
        pipeline_result[:ai_refinement] = { skipped: true, reason: skip_ai_reason }
      end
      
      # Step 5: Calculate comprehensive metrics
      Rails.logger.info "Step 5: Calculating metrics for session #{@session.id}"
      final_issues = pipeline_result.dig(:ai_refinement, :refined_issues) || rule_issues
      metrics_data = calculate_comprehensive_metrics(transcript_data, final_issues)
      pipeline_result[:metrics] = metrics_data
      
      # Step 6: Generate embeddings for future personalization
      if should_generate_embeddings?
        Rails.logger.info "Step 6: Generating embeddings for session #{@session.id}"
        embeddings_data = generate_session_embeddings(transcript_data, final_issues)
        pipeline_result[:embeddings] = embeddings_data
      else
        Rails.logger.info "Step 6: Skipping embedding generation"
        pipeline_result[:embeddings] = { skipped: true }
      end
      
      # Update processing metadata
      pipeline_result[:processing_metadata][:completed_at] = Time.current
      pipeline_result[:processing_metadata][:total_duration_seconds] = processing_duration
      
      pipeline_result
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
      
      unless transcription_result[:success]
        raise TranscriptionError, "Transcription failed: #{transcription_result[:error]}"
      end
      
      # Validate transcription quality
      validate_transcription_quality(transcription_result[:data])
      
      transcription_result[:data]
    end
    
    def analyze_with_rules(transcript_data)
      rule_detector = Analysis::RuleDetector.new(
        transcript_data,
        language: @session.language
      )
      
      begin
        detected_issues = rule_detector.detect_all_issues
        
        # Store issues in database
        store_detected_issues(detected_issues, 'rule')
        
        Rails.logger.info "Detected #{detected_issues.length} rule-based issues"
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
          store_detected_issues(refinement_result[:refined_issues], 'ai_refined')
        end
        
        Rails.logger.info "AI refinement completed: #{refinement_result[:metadata][:ai_segments_analyzed]} segments analyzed"
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
    
    def calculate_comprehensive_metrics(transcript_data, issues)
      metrics_calculator = Analysis::Metrics.new(
        transcript_data,
        issues,
        language: @session.language
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
      return { skipped: true, reason: 'Embeddings disabled' } unless embedding_service_available?
      
      begin
        embeddings_service = Ai::Embeddings.new(
          model: @options.dig(:embeddings, :model) || 'text-embedding-3-small'
        )
        
        # Temporarily store key data in session for embedding generation
        @session.update!(analysis_data: @session.analysis_data.merge({
          'transcript' => transcript_data[:transcript],
          'key_segments' => extract_key_segments(transcript_data, issues)
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
          pattern: issue_data[:pattern],
          category: issue_data[:category],
          metadata: extract_issue_metadata(issue_data)
        }
        
        Issue.create!(issue_attributes)
      end
    end
    
    def finalize_session(pipeline_result)
      # Build comprehensive analysis data
      analysis_data = {
        transcript: pipeline_result.dig(:transcription, :transcript),
        processing_state: 'completed',
        overall_score: pipeline_result.dig(:metrics, :overall_scores, :overall_score) || 0,
        metrics: pipeline_result[:metrics],
        pipeline_metadata: pipeline_result[:processing_metadata],
        ai_insights: pipeline_result.dig(:ai_refinement, :ai_insights) || [],
        coaching_recommendations: pipeline_result.dig(:ai_refinement, :coaching_recommendations) || {}
      }
      
      # Update session with final results
      @session.update!(
        analysis_data: analysis_data,
        processing_state: 'completed',
        completed: true,
        processed_at: Time.current
      )
      
      Rails.logger.info "Session #{@session.id} finalized successfully"
      
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
      update_session_state('failed', user_friendly_message)
      
      # Clean up any temp files even on error
      cleanup_temp_files(@pipeline_result) if defined?(@pipeline_result)
    end
    
    def update_session_state(state, error_message = nil)
      updates = {
        processing_state: state,
        incomplete_reason: error_message
      }
      
      updates[:completed] = false if state == 'failed'
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
      @session.processing_state != 'failed'
    end
    
    def ai_service_available?
      ENV['OPENAI_API_KEY'].present?
    end
    
    def embedding_service_available?
      ai_service_available? # Same requirement for now
    end
    
    def sufficient_content_for_ai?
      return false unless @session.analysis_data['transcript'].present?
      
      transcript = @session.analysis_data['transcript']
      word_count = transcript.split.length
      
      word_count >= 50 # Minimum 50 words for meaningful AI analysis
    end
    
    def user_has_ai_quota?
      # Placeholder for quota checking logic
      # Could check subscription status, daily limits, etc.
      true
    end
    
    def skip_ai_reason
      return 'disabled_by_option' if @options[:skip_ai]
      return 'api_key_missing' unless ai_service_available?
      return 'insufficient_content' unless sufficient_content_for_ai?
      return 'quota_exceeded' unless user_has_ai_quota?
      'unknown'
    end
    
    def determine_transcription_model
      # Could be enhanced with user preferences or content analysis
      case @session.language
      when 'en' then 'nova-2'
      when 'pt' then 'nova-2'
      else 'nova'
      end
    end
    
    def validate_transcription_quality(transcript_data)
      # Basic validation
      unless transcript_data[:transcript].present?
        raise TranscriptionError, "Empty transcript received"
      end
      
      unless transcript_data[:words].present?
        raise TranscriptionError, "No word-level timing data received"
      end
      
      # Check minimum quality thresholds
      word_count = transcript_data[:words].length
      if word_count < 5
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
      high_priority_issues = issues.select { |i| i[:severity] == 'high' }
      high_priority_issues.first(3).each do |issue|
        segments << {
          type: 'issue_context',
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
            type: 'representative_sample',
            start_ms: segment_words.first[:start],
            end_ms: segment_words.last[:end],
            text: segment_words.map { |w| w[:word] }.join(' ')
          }
        end
      end
      
      segments
    end
    
    def map_source_type(source_type)
      case source_type
      when 'rule' then 'rule'
      when 'ai_refined' then 'ai'
      else 'rule'
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
        'media_extraction'
      when TranscriptionError
        'transcription'
      when AnalysisError
        'analysis'
      when Ai::Client::ClientError, Ai::Client::RateLimitError, Ai::Client::AuthenticationError
        'ai_processing'
      else
        'unknown'
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
  end
end