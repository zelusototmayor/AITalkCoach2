module Analysis
  class AiRefiner
    class RefinerError < StandardError; end

    DEFAULT_MAX_AI_SEGMENTS = 5
    DEFAULT_CONFIDENCE_THRESHOLD = 0.7
    DEFAULT_CACHE_TTL = 6.hours

    # Performance optimization: Use faster model for coaching (creative task)
    ANALYSIS_MODEL = ENV["AI_MODEL_COACH"] || "gpt-4o"
    COACHING_MODEL = ENV["AI_MODEL_COACHING"] || "gpt-4o-mini"

    # Feature flag for parallel processing (set to false to disable if issues arise)
    ENABLE_PARALLEL_PROCESSING = ENV.fetch("ENABLE_PARALLEL_AI_PROCESSING", "true") == "true"

    def initialize(session, options = {})
      @session = session
      @options = options
      @ai_client = Ai::Client.new(model: ANALYSIS_MODEL)
      @coaching_client = Ai::Client.new(model: COACHING_MODEL)
      @max_ai_segments = options[:max_ai_segments] || DEFAULT_MAX_AI_SEGMENTS
      @confidence_threshold = options[:confidence_threshold] || DEFAULT_CONFIDENCE_THRESHOLD
      @cache_ttl = options[:cache_ttl] || DEFAULT_CACHE_TTL
    end

    def refine_analysis(transcript_data, rule_based_issues)
      refined_results = {
        refined_issues: [],
        ai_insights: [],
        segment_analyses: [], # Deprecated but kept for compatibility
        coaching_recommendations: [],
        metadata: {
          rule_issues_count: rule_based_issues.length,
          ai_segments_analyzed: 0, # Always 0 now (no segments)
          cache_hits: 0,
          processing_time_ms: 0,
          parallel_processing_enabled: ENABLE_PARALLEL_PROCESSING
        }
      }

      start_time = Time.current

      begin
        if ENABLE_PARALLEL_PROCESSING
          # OPTIMIZED: Run AI analysis and coaching in parallel
          refined_issues, ai_analysis, coaching_advice, timing_metadata =
            refine_analysis_parallel(transcript_data, rule_based_issues, start_time)
        else
          # FALLBACK: Sequential processing (original behavior)
          refined_issues, ai_analysis, coaching_advice, timing_metadata =
            refine_analysis_sequential(transcript_data, rule_based_issues, start_time)
        end

        # Compile final results
        refined_results.update(
          refined_issues: refined_issues,
          ai_insights: ai_analysis[:speech_quality] || {},
          segment_analyses: [], # No longer used
          coaching_recommendations: coaching_advice,
          metadata: refined_results[:metadata].merge(timing_metadata)
        )

      rescue => e
        Rails.logger.error "AiRefiner error for session #{@session.id}: #{e.message}"
        Rails.logger.error e.backtrace.first(5).join("\n")

        # Return original rule-based results with error info
        refined_results.update(
          refined_issues: rule_based_issues,
          error: e.message,
          fallback_mode: true
        )
      end

      refined_results
    end

    private

    # OPTIMIZED: Hybrid parallel processing of AI analysis and coaching
    # Runs both in parallel, then conditionally regenerates coaching if filler counts differ
    def refine_analysis_parallel(transcript_data, rule_based_issues, start_time)
      Rails.logger.info "[Session #{@session.id}] Starting PARALLEL AI processing (analysis + coaching)"

      analysis_start = Time.current
      coaching_start = nil
      analysis_duration = nil
      coaching_duration = nil
      coaching_regenerated = false
      regeneration_reason = nil

      begin
        # Execute both AI operations concurrently
        analysis_future = Concurrent::Promises.future do
          Thread.current[:name] = "ai_analysis_#{@session.id}"
          perform_comprehensive_analysis(transcript_data, rule_based_issues)
        end

        coaching_future = Concurrent::Promises.future do
          Thread.current[:name] = "ai_coaching_#{@session.id}"
          coaching_start = Time.current
          # Use rule-based issues for preliminary coaching
          # May be regenerated if counts differ significantly
          generate_coaching_recommendations(rule_based_issues)
        end

        # Wait for both to complete with timeout protection
        ai_analysis, preliminary_coaching = Concurrent::Promises.zip(
          analysis_future,
          coaching_future
        ).value!(120) # 120 second timeout for both operations

        analysis_duration = ((Time.current - analysis_start) * 1000).round
        coaching_duration = coaching_start ? ((Time.current - coaching_start) * 1000).round : 0

        Rails.logger.info "[Session #{@session.id}] Parallel processing completed - " \
                         "Analysis: #{analysis_duration}ms, Preliminary coaching: #{coaching_duration}ms"

        # Process the AI analysis results
        refined_issues = process_comprehensive_analysis_results(ai_analysis, transcript_data)

        # HYBRID OPTIMIZATION: Check if we need to regenerate coaching with accurate counts
        coaching_advice = preliminary_coaching

        if issue_counts_differ_significantly?(rule_based_issues, refined_issues)
          Rails.logger.info "[Session #{@session.id}] Filler counts differ significantly - " \
                           "regenerating coaching with AI-validated issues for accuracy"

          regeneration_start = Time.current
          coaching_advice = generate_coaching_recommendations(refined_issues)
          regeneration_duration = ((Time.current - regeneration_start) * 1000).round

          coaching_regenerated = true
          regeneration_reason = "filler_count_mismatch"
          coaching_duration = regeneration_duration # Update to reflect regeneration time

          Rails.logger.info "[Session #{@session.id}] Coaching regenerated with accurate counts " \
                           "in #{regeneration_duration}ms"
        else
          Rails.logger.info "[Session #{@session.id}] Using preliminary coaching (counts are similar)"
        end

        timing_metadata = {
          ai_segments_analyzed: 0,
          processing_time_ms: ((Time.current - start_time) * 1000).round,
          analysis_duration_ms: analysis_duration,
          coaching_duration_ms: coaching_duration,
          coaching_regenerated: coaching_regenerated,
          regeneration_reason: regeneration_reason,
          optimization: coaching_regenerated ? "hybrid_parallel_v1_regenerated" : "hybrid_parallel_v1",
          model_analysis: ANALYSIS_MODEL,
          model_coaching: COACHING_MODEL
        }

        [ refined_issues, ai_analysis, coaching_advice, timing_metadata ]

      rescue Concurrent::TimeoutError => e
        Rails.logger.error "[Session #{@session.id}] Parallel AI processing timeout after 120s"
        # Fallback to sequential processing on timeout
        Rails.logger.warn "[Session #{@session.id}] Falling back to sequential processing"
        refine_analysis_sequential(transcript_data, rule_based_issues, start_time)

      rescue => e
        Rails.logger.error "[Session #{@session.id}] Parallel processing failed: #{e.message}"
        raise # Re-raise to be caught by outer rescue
      end
    end

    # FALLBACK: Sequential processing (original behavior)
    def refine_analysis_sequential(transcript_data, rule_based_issues, start_time)
      Rails.logger.info "[Session #{@session.id}] Starting SEQUENTIAL AI processing"

      analysis_start = Time.current
      ai_analysis = perform_comprehensive_analysis(transcript_data, rule_based_issues)
      analysis_duration = ((Time.current - analysis_start) * 1000).round

      refined_issues = process_comprehensive_analysis_results(ai_analysis, transcript_data)

      coaching_start = Time.current
      coaching_advice = generate_coaching_recommendations(refined_issues)
      coaching_duration = ((Time.current - coaching_start) * 1000).round

      Rails.logger.info "[Session #{@session.id}] Sequential processing completed - " \
                       "Total: #{analysis_duration + coaching_duration}ms"

      timing_metadata = {
        ai_segments_analyzed: 0,
        processing_time_ms: ((Time.current - start_time) * 1000).round,
        analysis_duration_ms: analysis_duration,
        coaching_duration_ms: coaching_duration,
        optimization: "sequential_v1",
        model_analysis: ANALYSIS_MODEL,
        model_coaching: COACHING_MODEL
      }

      [ refined_issues, ai_analysis, coaching_advice, timing_metadata ]
    end

    # NEW: Perform comprehensive analysis in a single API call
    def perform_comprehensive_analysis(transcript_data, rule_based_issues)
      # Create cache key for this analysis
      transcript_hash = Digest::MD5.hexdigest(transcript_data[:transcript] || "")
      issues_hash = Digest::MD5.hexdigest(rule_based_issues.map { |i| "#{i[:kind]}:#{i[:text]}" }.join("|"))

      cache_key = Ai::Cache.analysis_cache_key(
        "#{transcript_hash}_#{issues_hash}",
        {
          type: "comprehensive_analysis",
          language: @session.language,
          user_level: determine_user_level,
          version: "1.0"
        }
      )

      # Check cache
      cached_result = Ai::Cache.get(cache_key, ttl: @cache_ttl)
      if cached_result
        @options[:metadata]&.[](:cache_hits)&.+(1)
        Rails.logger.info "Comprehensive analysis cache hit for session #{@session.id}"
        return cached_result
      end

      # Build prompt
      prompt_builder = Ai::PromptBuilder.new(
        "comprehensive_speech_analysis",
        language: @session.language
      )

      analysis_data = {
        transcript: transcript_data[:transcript] || "",
        rule_issues: rule_based_issues,
        context: {
          duration_seconds: transcript_data.dig(:metadata, :duration) || 0,
          word_count: transcript_data[:words]&.length || 0,
          user_level: determine_user_level
        }
      }

      messages = prompt_builder.build_messages(analysis_data)

      # Single API call with retries
      retries = 0
      max_retries = 3

      begin
        Rails.logger.info "Calling comprehensive analysis API for session #{@session.id}"
        response = @ai_client.chat_completion(
          messages,
          tool_schema: prompt_builder.tool_schema,
          prompt_type: prompt_builder.prompt_type
          # Note: Timeout is handled by the RetryHandler in the AI client
        )

        analysis_result = response[:parsed_content]

        unless analysis_result && analysis_result["summary"]
          raise "Invalid analysis format: missing required fields"
        end

        # Cache successful analysis
        Ai::Cache.set(cache_key, analysis_result, ttl: @cache_ttl)

        Rails.logger.info "Comprehensive analysis completed: #{analysis_result['summary']['total_filler_count']} fillers, #{analysis_result['summary']['total_valid_issues']} validated issues"

        analysis_result

      rescue => e
        retries += 1
        if retries < max_retries
          wait_time = (2 ** retries) # Exponential backoff: 2s, 4s, 8s
          Rails.logger.warn "Comprehensive analysis failed (attempt #{retries}/#{max_retries}), retrying in #{wait_time}s: #{e.message}"
          sleep(wait_time)
          retry
        else
          Rails.logger.error "Comprehensive analysis failed after #{max_retries} attempts: #{e.message}"
          raise
        end
      end
    end

    # NEW: Process results from comprehensive analysis
    def process_comprehensive_analysis_results(ai_analysis, transcript_data)
      refined_issues = []

      # Process filler words
      filler_words = ai_analysis["filler_words"] || []
      filler_words.each do |filler|
        # Find timing info from transcript
        timing = find_timing_for_text(filler["text_snippet"], transcript_data[:words] || [], filler["start_ms"])

        refined_issues << {
          kind: "filler_word",
          start_ms: timing[:start_ms],
          end_ms: timing[:end_ms],
          text: filler["text_snippet"],
          filler_word: filler["word"],
          source: "ai",
          rationale: filler["rationale"],
          tip: generate_filler_word_tip(filler["word"]),
          severity: filler["severity"] || "medium",
          ai_confidence: filler["confidence"],
          category: "filler_words",
          matched_words: [ filler["word"] ],
          validation_status: "ai_detected"
        }
      end

      # Process validated issues
      validated_issues = ai_analysis["validated_issues"] || []
      validated_issues.each do |issue|
        # Try to find original rule issue for timing
        original_issue = find_original_rule_issue(issue["original_detection"], issue["context_text"])

        refined_issues << {
          kind: issue["original_detection"],
          start_ms: original_issue&.[](:start_ms) || 0,
          end_ms: original_issue&.[](:end_ms) || 1000,
          text: issue["context_text"],
          source: "ai_validated",
          rationale: issue["impact_description"],
          tip: issue["coaching_recommendation"],
          severity: issue["severity"],
          ai_confidence: issue["confidence"],
          category: categorize_issue(issue["original_detection"]),
          validation_status: issue["validation"],
          ai_priority: issue["priority"],
          practice_exercise: issue["practice_exercise"]
        }
      end

      # Filter by confidence threshold
      if @confidence_threshold > 0
        refined_issues = refined_issues.select do |issue|
          (issue[:ai_confidence] || 0.8) >= @confidence_threshold
        end
      end

      refined_issues.sort_by { |issue| issue[:start_ms] }
    end

    # Helper to find original rule issue
    def find_original_rule_issue(kind, context_text)
      return nil unless @session.issues.any?

      @session.issues.find do |issue|
        issue.kind == kind && similar_text?(issue.text, context_text)
      end&.as_json&.symbolize_keys
    end

    # Helper to categorize issues
    def categorize_issue(kind)
      case kind.to_s
      when /filler/
        "filler_words"
      when /sentence.*structure/, /grammar/, /incomplete.*thought/, /run.*on/
        "sentence_structure_issues"
      when /pace/
        "pace_issues"
      when /clarity/
        "clarity_issues"
      else
        "other_issues"
      end
    end

    # DEPRECATED: Segment-based analysis (replaced by comprehensive analysis)
    # Kept temporarily for rollback compatibility - will be removed in future version
    def build_analysis_candidates(transcript_data, rule_based_issues)
      # This method is no longer called
      raise "build_analysis_candidates is deprecated - use perform_comprehensive_analysis instead"

      candidate_builder = CandidateBuilder.new(
        transcript_data,
        rule_based_issues,
        max_candidates: @max_ai_segments * 2, # Build extra for selection
        min_segment_duration: 3000, # 3 seconds
        max_segment_duration: 20000 # 20 seconds
      )

      candidates = candidate_builder.build_candidates
      Rails.logger.info "Built #{candidates.length} candidates for AI analysis"
      candidates
    end

    # DEPRECATED: No longer used (comprehensive analysis doesn't use segments)
    def select_segments_for_ai_analysis(candidates)
      raise "select_segments_for_ai_analysis is deprecated"

      return [] if candidates.empty?

      # Evaluate each candidate for AI analysis potential
      evaluated_candidates = candidates.map do |candidate|
        evaluation = evaluate_candidate_for_ai_analysis(candidate)
        candidate.merge(ai_evaluation: evaluation)
      end

      # Select top candidates that are worth AI analysis
      selected = evaluated_candidates
        .select { |c| c[:ai_evaluation][:recommended_for_ai_analysis] }
        .sort_by { |c| -c[:ai_evaluation][:evaluation][:overall_score] }
        .first(@max_ai_segments)

      Rails.logger.info "Selected #{selected.length} segments for AI analysis"
      selected
    end

    def evaluate_candidate_for_ai_analysis(candidate)
      cache_key = Ai::Cache.analysis_cache_key(
        Digest::MD5.hexdigest(candidate[:text]),
        { type: "segment_evaluation", version: "1.0" }
      )

      cached_result = Ai::Cache.get(cache_key, ttl: @cache_ttl)
      if cached_result
        @options[:metadata]&.[](:cache_hits)&.+(1)
        return cached_result
      end

      prompt_builder = Ai::PromptBuilder.new("segment_evaluation")

      evaluation_data = {
        segment: candidate,
        context: {
          session_context: {
            total_duration: @session.analysis_data.dig("metadata", "duration_ms") || 0,
            user_level: determine_user_level
          }
        },
        related_issues: find_related_rule_issues(candidate)
      }

      messages = prompt_builder.build_messages(evaluation_data)

      begin
        response = @ai_client.chat_completion(
          messages,
          tool_schema: prompt_builder.tool_schema,
          prompt_type: prompt_builder.prompt_type
        )
        evaluation = response[:parsed_content] || {}

        # Cache successful evaluations
        Ai::Cache.set(cache_key, evaluation, ttl: @cache_ttl)

        evaluation
      rescue => e
        Rails.logger.warn "AI segment evaluation failed: #{e.message}"
        # Return default evaluation that doesn't recommend AI analysis
        {
          evaluation: { overall_score: 0.3 },
          recommended_for_ai_analysis: false,
          error: e.message
        }
      end
    end

    def analyze_segments_with_ai(selected_segments, transcript_data)
      ai_results = {
        segments: [],
        insights: []
      }

      selected_segments.each do |segment|
        segment_analysis = analyze_segment_with_ai(segment, transcript_data)

        if segment_analysis && segment_analysis[:success]
          ai_results[:segments] << {
            segment: segment,
            analysis: segment_analysis[:analysis],
            confidence: segment_analysis[:confidence] || 0.8
          }

          # Extract insights from the analysis
          if segment_analysis[:analysis][:coaching_insights]
            ai_results[:insights].concat(segment_analysis[:analysis][:coaching_insights])
          end
        end
      end

      ai_results
    end

    def analyze_segment_with_ai(segment, transcript_data)
      # Create cache key for this specific segment analysis
      cache_key = Ai::Cache.analysis_cache_key(
        Digest::MD5.hexdigest(segment[:text]),
        {
          type: "speech_analysis",
          user_level: determine_user_level,
          version: "1.0"
        }
      )

      cached_result = Ai::Cache.get(cache_key, ttl: @cache_ttl)
      if cached_result
        @options[:metadata]&.[](:cache_hits)&.+(1)
        return { success: true, analysis: cached_result, cached: true }
      end

      prompt_builder = Ai::PromptBuilder.new(
        "speech_analysis",
        language: @session.language,
        target_audience: determine_target_audience
      )

      analysis_data = {
        transcript: segment[:text],
        context: {
          duration_seconds: segment[:duration_ms] / 1000.0,
          word_count: segment[:word_count],
          speech_type: determine_speech_type,
          target_audience: determine_target_audience
        },
        detected_issues: find_related_rule_issues(segment)
      }

      messages = prompt_builder.build_messages(analysis_data)

      begin
        response = @ai_client.chat_completion(
          messages,
          tool_schema: prompt_builder.tool_schema,
          prompt_type: prompt_builder.prompt_type
        )
        analysis = response[:parsed_content]

        if analysis && analysis["overall_assessment"]
          # Cache successful analysis
          Ai::Cache.set(cache_key, analysis, ttl: @cache_ttl)

          {
            success: true,
            analysis: analysis,
            confidence: calculate_analysis_confidence(analysis),
            usage: response[:usage]
          }
        else
          Rails.logger.warn "AI analysis returned invalid format for segment"
          { success: false, error: "Invalid analysis format" }
        end

      rescue => e
        Rails.logger.error "AI segment analysis failed: #{e.message}"
        { success: false, error: e.message }
      end
    end

    # DEPRECATED: Replaced by comprehensive analysis which does all of this in one call
    def classify_rule_issues_with_ai(rule_based_issues, transcript_data)
      raise "classify_rule_issues_with_ai is deprecated - use perform_comprehensive_analysis instead"

      return rule_based_issues if rule_based_issues.empty?

      # Split filler words from other issues for specialized processing
      filler_word_issues = rule_based_issues.select { |issue| issue[:kind] == "filler_word" }
      other_issues = rule_based_issues.reject { |issue| issue[:kind] == "filler_word" }

      classified_issues = []

      # For filler words: Let AI do fresh analysis from transcript (ignore rule detections)
      Rails.logger.info "Sending full transcript to AI for fresh filler word analysis (ignoring #{filler_word_issues.length} rule-based detections)"
      ai_detected_fillers = detect_filler_words_with_ai(transcript_data)
      classified_issues.concat(ai_detected_fillers)

      # Process other issues with standard classification
      if other_issues.any?
        Rails.logger.info "Classifying #{other_issues.length} non-filler issues with AI"
        issue_groups = other_issues.each_slice(10).to_a

        issue_groups.each do |issue_group|
          classified_group = classify_issue_group_with_ai(issue_group, transcript_data)
          classified_issues.concat(classified_group) if classified_group
        end
      end

      classified_issues.any? ? classified_issues : rule_based_issues
    end

    def classify_issue_group_with_ai(issues, transcript_data)
      # Create cache key for this issue group
      issues_hash = Digest::MD5.hexdigest(issues.map { |i| "#{i[:kind]}:#{i[:text]}" }.join("|"))
      cache_key = Ai::Cache.classification_cache_key(
        issues_hash,
        { user_level: determine_user_level, version: "1.0" }
      )

      cached_result = Ai::Cache.get(cache_key, ttl: @cache_ttl)
      if cached_result
        @options[:metadata]&.[](:cache_hits)&.+(1)
        return cached_result
      end

      prompt_builder = Ai::PromptBuilder.new("issue_classification")

      classification_data = {
        issues: issues,
        context: {
          user_level: determine_user_level,
          session_count: determine_session_count,
          previous_issues: determine_previous_issues_pattern
        }
      }

      messages = prompt_builder.build_messages(classification_data)

      begin
        response = @ai_client.chat_completion(
          messages,
          tool_schema: prompt_builder.tool_schema,
          prompt_type: prompt_builder.prompt_type
        )
        classification = response[:parsed_content]

        if classification && classification["validated_issues"]
          # Process validated issues and merge back with original data
          refined_issues = merge_classification_with_original_issues(issues, classification)

          # Cache the result
          Ai::Cache.set(cache_key, refined_issues, ttl: @cache_ttl)

          refined_issues
        else
          Rails.logger.warn "AI classification returned invalid format"
          issues # Return original issues
        end

      rescue => e
        Rails.logger.error "AI issue classification failed: #{e.message}"
        issues # Return original issues on error
      end
    end

    # DEPRECATED: Replaced by comprehensive analysis
    def detect_filler_words_with_ai(transcript_data)
      raise "detect_filler_words_with_ai is deprecated - use perform_comprehensive_analysis instead"

      # Create cache key for this transcript's filler word detection
      transcript_hash = Digest::MD5.hexdigest(transcript_data[:transcript] || "")
      cache_key = Ai::Cache.analysis_cache_key(
        transcript_hash,
        {
          type: "filler_word_detection",
          language: @session.language,
          version: "2.0"
        }
      )

      cached_result = Ai::Cache.get(cache_key, ttl: @cache_ttl)
      if cached_result
        @options[:metadata]&.[](:cache_hits)&.+(1)
        return cached_result
      end

      prompt_builder = Ai::PromptBuilder.new(
        "filler_word_detection",
        language: @session.language
      )

      detection_data = {
        transcript: transcript_data[:transcript] || "",
        words: transcript_data[:words] || [],
        context: {
          duration_seconds: transcript_data.dig(:metadata, :duration) || 0,
          word_count: transcript_data[:words]&.length || 0
        }
      }

      messages = prompt_builder.build_messages(detection_data)

      begin
        response = @ai_client.chat_completion(
          messages,
          tool_schema: prompt_builder.tool_schema,
          prompt_type: prompt_builder.prompt_type
        )
        detection_result = response[:parsed_content]

        if detection_result && detection_result["filler_words"]
          # Process detection results and convert to issue format
          filler_issues = process_filler_detection_results(
            detection_result,
            transcript_data
          )

          # Cache the result
          Ai::Cache.set(cache_key, filler_issues, ttl: @cache_ttl)

          Rails.logger.info "AI detected #{detection_result['summary']['total_detected']} filler words " \
                           "(Rate: #{detection_result['summary']['filler_rate_per_minute']} per minute)"

          filler_issues
        else
          Rails.logger.warn "AI filler word detection returned invalid format"
          []
        end

      rescue => e
        Rails.logger.error "AI filler word detection failed: #{e.message}"
        []
      end
    end

    def process_filler_detection_results(detection_result, transcript_data)
      filler_issues = []
      words = transcript_data[:words] || []

      # Process AI-detected filler words
      detected_fillers = detection_result["filler_words"] || []
      detected_fillers.each do |filler|
        # Try to find timing info from transcript
        timing = find_timing_for_text(filler["text_snippet"], words, filler["start_ms"])

        filler_issues << {
          kind: "filler_word",
          start_ms: timing[:start_ms],
          end_ms: timing[:end_ms],
          text: filler["text_snippet"],
          filler_word: filler["word"], # Exact filler word for highlighting
          source: "ai",
          rationale: filler["rationale"],
          tip: generate_filler_word_tip(filler["word"]),
          severity: filler["severity"] || "medium",
          ai_confidence: filler["confidence"],
          category: "filler_words",
          matched_words: [ filler["word"] ],
          validation_status: "ai_detected"
        }
      end

      # Filter by confidence threshold
      if @confidence_threshold > 0
        filler_issues = filler_issues.select do |issue|
          (issue[:ai_confidence] || 0.8) >= @confidence_threshold
        end
      end

      filler_issues.sort_by { |issue| issue[:start_ms] }
    end

    def find_matching_issue(issues, validated_filler)
      # Try to match by timing first (most accurate)
      if validated_filler["start_ms"]
        match = issues.find do |issue|
          time_overlap = (issue[:start_ms] - validated_filler["start_ms"]).abs < 500 # 500ms tolerance
          time_overlap
        end
        return match if match
      end

      # Fallback to text matching
      issues.find do |issue|
        similar_text?(issue[:text], validated_filler["text_snippet"])
      end
    end

    def find_timing_for_text(text_snippet, words, suggested_start_ms = nil)
      # If AI provided timing, use that
      return { start_ms: suggested_start_ms, end_ms: suggested_start_ms + 500 } if suggested_start_ms

      # Try to find the text in the word-level data
      text_words = text_snippet.downcase.split
      return { start_ms: 0, end_ms: 500 } if text_words.empty?

      # Search for matching sequence in words
      words.each_cons(text_words.length) do |word_group|
        group_text = word_group.map { |w| (w[:punctuated_word] || w[:word]).downcase }.join(" ")
        if group_text.include?(text_words.first)
          return {
            start_ms: word_group.first[:start],
            end_ms: word_group.last[:end]
          }
        end
      end

      # Default fallback
      { start_ms: 0, end_ms: 500 }
    end

    def generate_filler_word_tip(word)
      tips = {
        "um" => 'Try pausing instead of using "um". Silence can be more powerful.',
        "uh" => 'Take a breath and pause instead of filling space with "uh".',
        "like" => 'Reduce casual "like" usage. Be more direct in your phrasing.',
        "you know" => 'Avoid "you know" - state your point directly with confidence.',
        "so" => 'Start sentences with your main point instead of "so".',
        "basically" => 'Remove unnecessary "basically" - just explain the concept directly.',
        "actually" => 'Use "actually" sparingly, only when genuinely correcting information.',
        "kind of" => 'Be more definitive. Replace "kind of" with specific descriptions.',
        "sort of" => 'Choose precise language instead of hedging with "sort of".'
      }

      tips[word.downcase] || "Work on reducing this filler word for clearer communication."
    end

    def merge_classification_with_original_issues(original_issues, classification)
      validated_issues = classification["validated_issues"] || []
      false_positives = classification["false_positives"] || []

      # Start with original issues and refine them
      refined_issues = original_issues.map do |original_issue|
        # Find corresponding AI validation
        ai_validation = validated_issues.find do |validated|
          validated["original_detection"] == original_issue[:kind] ||
          similar_text?(original_issue[:text], validated["context_text"])
        end

        if ai_validation
          # Merge AI insights with original detection
          original_issue.merge(
            ai_confidence: ai_validation["confidence"] || 0.8,
            ai_severity: ai_validation["severity"],
            ai_coaching_tip: ai_validation["coaching_recommendation"],
            ai_priority: ai_validation["priority"],
            source: "rule_ai_validated",
            validation_status: "confirmed"
          )
        else
          # Check if it's marked as false positive
          false_positive = false_positives.find do |fp|
            fp["original_detection"] == original_issue[:kind]
          end

          if false_positive && false_positive["confidence_override"] < 0.3
            # Mark as low confidence but keep for user review
            original_issue.merge(
              ai_confidence: false_positive["confidence_override"],
              validation_status: "disputed",
              ai_note: false_positive["reason"]
            )
          else
            # Keep original with default confidence
            original_issue.merge(
              ai_confidence: 0.6,
              validation_status: "not_reviewed"
            )
          end
        end
      end

      # Filter out very low confidence issues if specified
      if @confidence_threshold > 0
        refined_issues = refined_issues.select do |issue|
          (issue[:ai_confidence] || 0.6) >= @confidence_threshold
        end
      end

      refined_issues
    end

    def merge_rule_and_ai_findings(rule_issues, classified_issues, ai_results)
      merged_issues = classified_issues.dup

      # Add AI-discovered issues from segment analysis
      ai_results[:segments].each do |segment_result|
        analysis = segment_result[:analysis]
        segment = segment_result[:segment]

        next unless analysis["improvement_areas"]

        analysis["improvement_areas"].each do |improvement|
          # Convert AI finding to issue format
          ai_issue = {
            kind: map_ai_category_to_issue_kind(improvement["category"]),
            start_ms: segment[:start_ms],
            end_ms: segment[:end_ms],
            text: extract_relevant_text(segment[:text], improvement["issue"]),
            source: "ai",
            rationale: improvement["issue"],
            tip: improvement["specific_recommendation"],
            severity: improvement["severity"],
            priority: improvement["priority"],
            ai_confidence: improvement["confidence"] || 0.8,
            category: improvement["category"],
            validation_status: "ai_generated"
          }

          # Check for duplicates with existing issues
          unless duplicate_issue_exists?(merged_issues, ai_issue)
            merged_issues << ai_issue
          end
        end
      end

      # Sort by start time and priority
      merged_issues.sort_by { |issue| [ issue[:start_ms], priority_sort_value(issue[:priority]) ] }
    end

    def generate_coaching_recommendations(merged_issues)
      return [] if merged_issues.empty?

      cache_key = Ai::Cache.coaching_cache_key(
        @session.user_id,
        Digest::MD5.hexdigest(determine_user_profile.to_json),
        Digest::MD5.hexdigest(merged_issues.map { |i| i[:kind] }.sort.join(","))
      )

      cached_advice = Ai::Cache.get(cache_key, ttl: @cache_ttl)
      if cached_advice
        @options[:metadata]&.[](:cache_hits)&.+(1)
        return cached_advice
      end

      prompt_builder = Ai::PromptBuilder.new(
        "coaching_advice",
        coaching_style: @options[:coaching_style] || "supportive"
      )

      # Retrieve coaching insights from session (Phase 3 enhancement)
      coaching_insights = @session.coaching_insights || {}

      coaching_data = {
        user_profile: determine_user_profile,
        recent_sessions: determine_recent_sessions,
        issue_trends: analyze_issue_trends(merged_issues),

        # Phase 3: Add current session insights for pattern-specific coaching
        current_session_insights: {
          standout_patterns: extract_standout_patterns(coaching_insights),
          micro_opportunities: extract_micro_opportunities(coaching_insights)
        }
      }

      messages = prompt_builder.build_messages(coaching_data)

      begin
        # Use dedicated coaching client (faster model for creative/generative task)
        response = @coaching_client.chat_completion(
          messages,
          tool_schema: prompt_builder.tool_schema,
          prompt_type: prompt_builder.prompt_type
        )
        coaching_advice = response[:parsed_content]

        if coaching_advice
          # Cache successful coaching advice
          Ai::Cache.set(cache_key, coaching_advice, ttl: @cache_ttl)
          coaching_advice
        else
          Rails.logger.warn "AI coaching advice returned invalid format"
          generate_fallback_coaching_advice(merged_issues)
        end

      rescue => e
        Rails.logger.error "AI coaching advice generation failed: #{e.message}"
        generate_fallback_coaching_advice(merged_issues)
      end
    end

    # Helper methods

    def find_related_rule_issues(segment)
      return [] unless @session.issues.any?

      @session.issues.where(
        "(start_ms BETWEEN ? AND ?) OR (end_ms BETWEEN ? AND ?) OR (start_ms <= ? AND end_ms >= ?)",
        segment[:start_ms], segment[:end_ms],
        segment[:start_ms], segment[:end_ms],
        segment[:start_ms], segment[:end_ms]
      ).map do |issue|
        {
          kind: issue.kind,
          severity: issue.severity,
          text: issue.text
        }
      end
    end

    def determine_user_level
      session_count = @session.user.sessions.count
      case session_count
      when 0..5 then "beginner"
      when 6..20 then "intermediate"
      else "advanced"
      end
    end

    def determine_target_audience
      # Could be enhanced with session metadata
      "professional"
    end

    def determine_speech_type
      # Could be enhanced with session categorization
      "presentation"
    end

    def determine_session_count
      @session.user.sessions.count
    end

    def determine_previous_issues_pattern
      @session.user.sessions
              .joins(:issues)
              .where("sessions.created_at > ?", 30.days.ago)
              .group("issues.kind")
              .count
              .keys
    end

    def determine_user_profile
      {
        session_count: determine_session_count,
        level: determine_user_level,
        goals: [ "clarity", "confidence" ], # Could be user-configurable
        practice_time: "10-15 minutes"
      }
    end

    def determine_recent_sessions
      @session.user.sessions
              .where("created_at > ?", 7.days.ago)
              .where.not(id: @session.id)
              .limit(5)
              .map do |session|
        {
          date: session.created_at.strftime("%Y-%m-%d"),
          overall_score: session.analysis_data.dig("overall_score") || 75,
          top_issues: session.issues.limit(3).pluck(:kind),
          duration_seconds: session.analysis_data.dig("metadata", "duration") || 0
        }
      end
    end

    def analyze_issue_trends(issues)
      issues.group_by { |i| i[:kind] }.transform_values do |issue_group|
        {
          count: issue_group.length,
          trend: "stable", # Would need historical data for real trends
          change_percentage: 0
        }
      end
    end

    def calculate_analysis_confidence(analysis)
      return 0.5 unless analysis.is_a?(Hash)

      # Calculate confidence based on analysis quality
      base_confidence = 0.7

      # Boost for specific recommendations
      if analysis.dig("improvement_areas")&.any? { |area| area["specific_recommendation"] }
        base_confidence += 0.1
      end

      # Boost for consistent scores
      assessment = analysis["overall_assessment"] || {}
      if assessment.values.select { |v| v.is_a?(Numeric) }.any?
        score_variance = calculate_score_variance(assessment)
        base_confidence += 0.1 if score_variance < 20 # Consistent scoring
      end

      [ base_confidence, 1.0 ].min
    end

    def calculate_score_variance(assessment)
      scores = assessment.values.select { |v| v.is_a?(Numeric) }
      return 0 if scores.length < 2

      mean = scores.sum.to_f / scores.length
      variance = scores.map { |s| (s - mean) ** 2 }.sum / scores.length
      Math.sqrt(variance)
    end

    def similar_text?(text1, text2)
      return false unless text1 && text2

      # Simple similarity check - could be enhanced with more sophisticated algorithms
      common_words = text1.downcase.split & text2.downcase.split
      total_words = (text1.split + text2.split).uniq.length

      return false if total_words == 0

      similarity = common_words.length.to_f / total_words
      similarity > 0.3
    end

    def map_ai_category_to_issue_kind(category)
      category_mapping = {
        "pace" => "pace_issue",
        "clarity" => "clarity_issue",
        "filler" => "filler_word",
        "professional" => "professionalism",
        "confidence" => "confidence_issue",
        "engagement" => "engagement_issue"
      }

      category_mapping[category.to_s.downcase] || "other"
    end

    def extract_relevant_text(full_text, issue_description)
      # Simple extraction - could be enhanced with NLP
      words = full_text.split

      # Return first 10-15 words as context
      words.first(15).join(" ") + (words.length > 15 ? "..." : "")
    end

    def duplicate_issue_exists?(existing_issues, new_issue)
      existing_issues.any? do |existing|
        # Check for overlapping time ranges and similar kinds
        time_overlap = time_ranges_overlap?(
          [ existing[:start_ms], existing[:end_ms] ],
          [ new_issue[:start_ms], new_issue[:end_ms] ]
        )

        kind_similar = existing[:kind] == new_issue[:kind] ||
                       similar_issue_kinds?(existing[:kind], new_issue[:kind])

        time_overlap && kind_similar
      end
    end

    def time_ranges_overlap?(range1, range2)
      range1[0] <= range2[1] && range2[0] <= range1[1]
    end

    def similar_issue_kinds?(kind1, kind2)
      # Group related issue kinds
      similar_groups = [
        %w[filler_word filler],
        %w[pace_issue pace_too_fast pace_too_slow],
        %w[clarity_issue articulation],
        %w[professionalism professional_issue]
      ]

      similar_groups.any? { |group| group.include?(kind1) && group.include?(kind2) }
    end

    def priority_sort_value(priority)
      case priority.to_s.downcase
      when "high" then 1
      when "medium" then 2
      when "low" then 3
      else 4
      end
    end

    # Hybrid Optimization: Check if filler word counts differ significantly
    # between rule-based and AI-validated issues
    #
    # @param rule_issues [Array<Hash>] Rule-based detected issues
    # @param ai_issues [Array<Hash>] AI-validated issues
    # @param threshold [Float] Percentage difference threshold (default: 20%)
    # @return [Boolean] true if counts differ by more than threshold
    def issue_counts_differ_significantly?(rule_issues, ai_issues, threshold: 0.20)
      rule_filler_count = rule_issues.count { |i| i[:kind] == "filler_word" }
      ai_filler_count = ai_issues.count { |i| i[:kind] == "filler_word" }

      # If both are zero, counts don't differ
      return false if rule_filler_count == 0 && ai_filler_count == 0

      # If one is zero and the other isn't, they differ significantly
      return true if rule_filler_count == 0 || ai_filler_count == 0

      # Calculate percentage difference based on rule-based count (baseline)
      diff_ratio = (rule_filler_count - ai_filler_count).abs.to_f / rule_filler_count

      Rails.logger.debug "[Session #{@session.id}] Filler count comparison: " \
                         "rule=#{rule_filler_count}, ai=#{ai_filler_count}, " \
                         "diff=#{(diff_ratio * 100).round(1)}%"

      diff_ratio >= threshold
    end

    def generate_fallback_coaching_advice(issues)
      # Simple rule-based coaching advice as fallback
      issue_counts = issues.group_by { |i| i[:kind] }.transform_values(&:count)
      top_issue = issue_counts.max_by { |_, count| count }&.first

      {
        focus_areas: [
          {
            skill: top_issue || "general_improvement",
            current_level: determine_user_level,
            target_improvement: "Reduce frequency by 30%",
            timeline: "1-2 weeks"
          }
        ],
        weekly_goals: [
          {
            goal: "Work on #{top_issue || 'speaking clarity'}",
            strategies: [ "Practice daily", "Record yourself" ],
            measurement: "Track improvement in next session",
            difficulty: "medium"
          }
        ],
        motivation_message: "Keep practicing - improvement comes with consistency!"
      }
    end

    # Phase 3: Extract standout patterns from coaching insights
    def extract_standout_patterns(coaching_insights)
      return [] if coaching_insights.blank?

      patterns = []

      # Pause patterns
      if coaching_insights["pause_patterns"].present?
        pause = coaching_insights["pause_patterns"]
        if pause["quality_breakdown"] == "mostly_good_with_awkward_long_pauses"
          patterns << "pause_consistency_low_but_improving"
        elsif pause["specific_issue"].present?
          patterns << "awkward_long_pauses: #{pause['specific_issue']}"
        end
      end

      # Pace patterns
      if coaching_insights["pace_patterns"].present?
        pace = coaching_insights["pace_patterns"]
        if pace["trajectory"] && pace["trajectory"] != "steady"
          patterns << "pace_#{pace['trajectory']}"
        end
        if pace["consistency"] && pace["consistency"] < 0.5
          patterns << "pace_inconsistent"
        end
      end

      # Energy patterns
      if coaching_insights["energy_patterns"].present?
        energy = coaching_insights["energy_patterns"]
        if energy["pattern"] == "low_energy_throughout"
          patterns << "energy_flat_throughout_session"
        elsif energy["needs_boost"]
          patterns << "energy_needs_boost"
        end
      end

      # Smoothness breakdown
      if coaching_insights["smoothness_breakdown"].present?
        smoothness = coaching_insights["smoothness_breakdown"]
        if smoothness["word_flow_excellent"] && smoothness["pause_flow_poor"]
          patterns << "word_pacing_excellent_but_pause_inconsistent"
        end
      end

      patterns.compact.first(3) # Return top 3 standout patterns
    end

    # Phase 3: Extract micro-opportunities from coaching insights
    def extract_micro_opportunities(coaching_insights)
      return [] if coaching_insights.blank?

      opportunities = []

      # Hesitation analysis
      if coaching_insights["hesitation_analysis"].present?
        hesitation = coaching_insights["hesitation_analysis"]
        if hesitation["pattern"] && hesitation["pattern"] != "distributed"
          opportunities << {
            type: "hesitation_location",
            pattern: hesitation["pattern"],
            suggestion: "Practice opening phrases to reduce sentence-start hesitations"
          }
        end
      end

      # Pause opportunities
      if coaching_insights["pause_patterns"].present?
        pause = coaching_insights["pause_patterns"]
        if pause["distribution"] && pause["distribution"]["optimal"] && pause["distribution"]["optimal"] > 60
          opportunities << {
            type: "pause_strength",
            insight: "#{pause['distribution']['optimal']}% of pauses are well-timed",
            suggestion: "Leverage this strength while working on other areas"
          }
        end
      end

      # Pace opportunities
      if coaching_insights["pace_patterns"].present?
        pace = coaching_insights["pace_patterns"]
        # Use user's optimal WPM range or defaults
        optimal_min = @session.user.optimal_wpm_min
        optimal_max = @session.user.optimal_wpm_max
        if pace["average_wpm"] && pace["average_wpm"].between?(optimal_min, optimal_max)
          opportunities << {
            type: "pace_strength",
            insight: "Natural conversational pace",
            suggestion: "Focus on maintaining this pace consistency"
          }
        end
      end

      opportunities.first(2) # Return top 2 micro-opportunities
    end
  end
end
