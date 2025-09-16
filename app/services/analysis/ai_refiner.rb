module Analysis
  class AiRefiner
    class RefinerError < StandardError; end
    
    DEFAULT_MAX_AI_SEGMENTS = 5
    DEFAULT_CONFIDENCE_THRESHOLD = 0.7
    DEFAULT_CACHE_TTL = 6.hours
    
    def initialize(session, options = {})
      @session = session
      @options = options
      @ai_client = Ai::Client.new
      @max_ai_segments = options[:max_ai_segments] || DEFAULT_MAX_AI_SEGMENTS
      @confidence_threshold = options[:confidence_threshold] || DEFAULT_CONFIDENCE_THRESHOLD
      @cache_ttl = options[:cache_ttl] || DEFAULT_CACHE_TTL
    end
    
    def refine_analysis(transcript_data, rule_based_issues)
      refined_results = {
        refined_issues: [],
        ai_insights: [],
        segment_analyses: [],
        coaching_recommendations: [],
        metadata: {
          rule_issues_count: rule_based_issues.length,
          ai_segments_analyzed: 0,
          cache_hits: 0,
          processing_time_ms: 0
        }
      }
      
      start_time = Time.current
      
      begin
        # Step 1: Build candidates for AI analysis
        candidates = build_analysis_candidates(transcript_data, rule_based_issues)
        
        # Step 2: Evaluate and select best segments for AI analysis
        selected_segments = select_segments_for_ai_analysis(candidates)
        
        # Step 3: Perform AI analysis on selected segments
        ai_results = analyze_segments_with_ai(selected_segments, transcript_data)
        
        # Step 4: Classify and validate rule-based issues with AI
        classified_issues = classify_rule_issues_with_ai(rule_based_issues, transcript_data)
        
        # Step 5: Merge and deduplicate findings
        merged_issues = merge_rule_and_ai_findings(rule_based_issues, classified_issues, ai_results)
        
        # Step 6: Generate personalized coaching recommendations
        coaching_advice = generate_coaching_recommendations(merged_issues)
        
        # Compile final results
        refined_results.update(
          refined_issues: merged_issues,
          ai_insights: ai_results[:insights] || [],
          segment_analyses: ai_results[:segments] || [],
          coaching_recommendations: coaching_advice,
          metadata: refined_results[:metadata].merge(
            ai_segments_analyzed: selected_segments.length,
            processing_time_ms: ((Time.current - start_time) * 1000).round
          )
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
    
    def build_analysis_candidates(transcript_data, rule_based_issues)
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
    
    def select_segments_for_ai_analysis(candidates)
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
        { type: 'segment_evaluation', version: '1.0' }
      )
      
      cached_result = Ai::Cache.get(cache_key, ttl: @cache_ttl)
      if cached_result
        @options[:metadata]&.[](:cache_hits)&.+(1)
        return cached_result
      end
      
      prompt_builder = Ai::PromptBuilder.new('segment_evaluation')
      
      evaluation_data = {
        segment: candidate,
        context: {
          session_context: {
            total_duration: @session.analysis_data.dig('metadata', 'duration_ms') || 0,
            user_level: determine_user_level
          }
        },
        related_issues: find_related_rule_issues(candidate)
      }
      
      messages = prompt_builder.build_messages(evaluation_data)
      
      begin
        response = @ai_client.chat_completion(messages, temperature: 0.2)
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
          type: 'speech_analysis',
          user_level: determine_user_level,
          version: '1.0'
        }
      )
      
      cached_result = Ai::Cache.get(cache_key, ttl: @cache_ttl)
      if cached_result
        @options[:metadata]&.[](:cache_hits)&.+(1)
        return { success: true, analysis: cached_result, cached: true }
      end
      
      prompt_builder = Ai::PromptBuilder.new(
        'speech_analysis',
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
        response = @ai_client.chat_completion(messages, temperature: 0.3)
        analysis = response[:parsed_content]
        
        if analysis && analysis['overall_assessment']
          # Cache successful analysis
          Ai::Cache.set(cache_key, analysis, ttl: @cache_ttl)
          
          return {
            success: true,
            analysis: analysis,
            confidence: calculate_analysis_confidence(analysis),
            usage: response[:usage]
          }
        else
          Rails.logger.warn "AI analysis returned invalid format for segment"
          return { success: false, error: 'Invalid analysis format' }
        end
        
      rescue => e
        Rails.logger.error "AI segment analysis failed: #{e.message}"
        return { success: false, error: e.message }
      end
    end
    
    def classify_rule_issues_with_ai(rule_based_issues, transcript_data)
      return rule_based_issues if rule_based_issues.empty?
      
      # Group issues for batch processing (more efficient)
      issue_groups = rule_based_issues.each_slice(10).to_a
      classified_issues = []
      
      issue_groups.each do |issue_group|
        classified_group = classify_issue_group_with_ai(issue_group, transcript_data)
        classified_issues.concat(classified_group) if classified_group
      end
      
      classified_issues.any? ? classified_issues : rule_based_issues
    end
    
    def classify_issue_group_with_ai(issues, transcript_data)
      # Create cache key for this issue group
      issues_hash = Digest::MD5.hexdigest(issues.map { |i| "#{i[:kind]}:#{i[:text]}" }.join('|'))
      cache_key = Ai::Cache.classification_cache_key(
        issues_hash,
        { user_level: determine_user_level, version: '1.0' }
      )
      
      cached_result = Ai::Cache.get(cache_key, ttl: @cache_ttl)
      if cached_result
        @options[:metadata]&.[](:cache_hits)&.+(1)
        return cached_result
      end
      
      prompt_builder = Ai::PromptBuilder.new('issue_classification')
      
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
        response = @ai_client.chat_completion(messages, temperature: 0.1)
        classification = response[:parsed_content]
        
        if classification && classification['validated_issues']
          # Process validated issues and merge back with original data
          refined_issues = merge_classification_with_original_issues(issues, classification)
          
          # Cache the result
          Ai::Cache.set(cache_key, refined_issues, ttl: @cache_ttl)
          
          return refined_issues
        else
          Rails.logger.warn "AI classification returned invalid format"
          return issues # Return original issues
        end
        
      rescue => e
        Rails.logger.error "AI issue classification failed: #{e.message}"
        return issues # Return original issues on error
      end
    end
    
    def merge_classification_with_original_issues(original_issues, classification)
      validated_issues = classification['validated_issues'] || []
      false_positives = classification['false_positives'] || []
      
      # Start with original issues and refine them
      refined_issues = original_issues.map do |original_issue|
        # Find corresponding AI validation
        ai_validation = validated_issues.find do |validated|
          validated['original_detection'] == original_issue[:kind] ||
          similar_text?(original_issue[:text], validated['context_text'])
        end
        
        if ai_validation
          # Merge AI insights with original detection
          original_issue.merge(
            ai_confidence: ai_validation['confidence'] || 0.8,
            ai_severity: ai_validation['severity'],
            ai_coaching_tip: ai_validation['coaching_recommendation'],
            ai_priority: ai_validation['priority'],
            source: 'rule_ai_validated',
            validation_status: 'confirmed'
          )
        else
          # Check if it's marked as false positive
          false_positive = false_positives.find do |fp|
            fp['original_detection'] == original_issue[:kind]
          end
          
          if false_positive && false_positive['confidence_override'] < 0.3
            # Mark as low confidence but keep for user review
            original_issue.merge(
              ai_confidence: false_positive['confidence_override'],
              validation_status: 'disputed',
              ai_note: false_positive['reason']
            )
          else
            # Keep original with default confidence
            original_issue.merge(
              ai_confidence: 0.6,
              validation_status: 'not_reviewed'
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
        
        next unless analysis['improvement_areas']
        
        analysis['improvement_areas'].each do |improvement|
          # Convert AI finding to issue format
          ai_issue = {
            kind: map_ai_category_to_issue_kind(improvement['category']),
            start_ms: segment[:start_ms],
            end_ms: segment[:end_ms],
            text: extract_relevant_text(segment[:text], improvement['issue']),
            source: 'ai',
            rationale: improvement['issue'],
            tip: improvement['specific_recommendation'],
            severity: improvement['severity'],
            priority: improvement['priority'],
            ai_confidence: improvement['confidence'] || 0.8,
            category: improvement['category'],
            validation_status: 'ai_generated'
          }
          
          # Check for duplicates with existing issues
          unless duplicate_issue_exists?(merged_issues, ai_issue)
            merged_issues << ai_issue
          end
        end
      end
      
      # Sort by start time and priority
      merged_issues.sort_by { |issue| [issue[:start_ms], priority_sort_value(issue[:priority])] }
    end
    
    def generate_coaching_recommendations(merged_issues)
      return [] if merged_issues.empty?
      
      cache_key = Ai::Cache.coaching_cache_key(
        @session.user_id,
        Digest::MD5.hexdigest(determine_user_profile.to_json),
        Digest::MD5.hexdigest(merged_issues.map { |i| i[:kind] }.sort.join(','))
      )
      
      cached_advice = Ai::Cache.get(cache_key, ttl: @cache_ttl)
      if cached_advice
        @options[:metadata]&.[](:cache_hits)&.+(1)
        return cached_advice
      end
      
      prompt_builder = Ai::PromptBuilder.new(
        'coaching_advice',
        coaching_style: @options[:coaching_style] || 'supportive'
      )
      
      coaching_data = {
        user_profile: determine_user_profile,
        recent_sessions: determine_recent_sessions,
        issue_trends: analyze_issue_trends(merged_issues)
      }
      
      messages = prompt_builder.build_messages(coaching_data)
      
      begin
        response = @ai_client.chat_completion(messages, temperature: 0.4)
        coaching_advice = response[:parsed_content]
        
        if coaching_advice
          # Cache successful coaching advice
          Ai::Cache.set(cache_key, coaching_advice, ttl: @cache_ttl)
          return coaching_advice
        else
          Rails.logger.warn "AI coaching advice returned invalid format"
          return generate_fallback_coaching_advice(merged_issues)
        end
        
      rescue => e
        Rails.logger.error "AI coaching advice generation failed: #{e.message}"
        return generate_fallback_coaching_advice(merged_issues)
      end
    end
    
    # Helper methods
    
    def find_related_rule_issues(segment)
      return [] unless @session.issues.any?
      
      @session.issues.where(
        '(start_ms BETWEEN ? AND ?) OR (end_ms BETWEEN ? AND ?) OR (start_ms <= ? AND end_ms >= ?)',
        segment[:start_ms], segment[:end_ms],
        segment[:start_ms], segment[:end_ms],
        segment[:start_ms], segment[:end_ms]
      ).map do |issue|
        {
          kind: issue.kind,
          severity: issue.severity,
          pattern: issue.pattern,
          text: issue.text
        }
      end
    end
    
    def determine_user_level
      session_count = @session.user.sessions.count
      case session_count
      when 0..5 then 'beginner'
      when 6..20 then 'intermediate'
      else 'advanced'
      end
    end
    
    def determine_target_audience
      # Could be enhanced with session metadata
      'professional'
    end
    
    def determine_speech_type
      # Could be enhanced with session categorization
      'presentation'
    end
    
    def determine_session_count
      @session.user.sessions.count
    end
    
    def determine_previous_issues_pattern
      @session.user.sessions
              .joins(:issues)
              .where('sessions.created_at > ?', 30.days.ago)
              .group('issues.kind')
              .count
              .keys
    end
    
    def determine_user_profile
      {
        session_count: determine_session_count,
        level: determine_user_level,
        goals: ['clarity', 'confidence'], # Could be user-configurable
        practice_time: '10-15 minutes'
      }
    end
    
    def determine_recent_sessions
      @session.user.sessions
              .where('created_at > ?', 7.days.ago)
              .where.not(id: @session.id)
              .limit(5)
              .map do |session|
        {
          date: session.created_at.strftime('%Y-%m-%d'),
          overall_score: session.analysis_data.dig('overall_score') || 75,
          top_issues: session.issues.limit(3).pluck(:kind),
          duration_seconds: session.analysis_data.dig('metadata', 'duration') || 0
        }
      end
    end
    
    def analyze_issue_trends(issues)
      issues.group_by { |i| i[:kind] }.transform_values do |issue_group|
        {
          count: issue_group.length,
          trend: 'stable', # Would need historical data for real trends
          change_percentage: 0
        }
      end
    end
    
    def calculate_analysis_confidence(analysis)
      return 0.5 unless analysis.is_a?(Hash)
      
      # Calculate confidence based on analysis quality
      base_confidence = 0.7
      
      # Boost for specific recommendations
      if analysis.dig('improvement_areas')&.any? { |area| area['specific_recommendation'] }
        base_confidence += 0.1
      end
      
      # Boost for consistent scores
      assessment = analysis['overall_assessment'] || {}
      if assessment.values.select { |v| v.is_a?(Numeric) }.any?
        score_variance = calculate_score_variance(assessment)
        base_confidence += 0.1 if score_variance < 20 # Consistent scoring
      end
      
      [base_confidence, 1.0].min
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
        'pace' => 'pace_issue',
        'clarity' => 'clarity_issue',
        'filler' => 'filler_word',
        'professional' => 'professionalism',
        'confidence' => 'confidence_issue',
        'engagement' => 'engagement_issue'
      }
      
      category_mapping[category.to_s.downcase] || 'other'
    end
    
    def extract_relevant_text(full_text, issue_description)
      # Simple extraction - could be enhanced with NLP
      words = full_text.split
      
      # Return first 10-15 words as context
      words.first(15).join(' ') + (words.length > 15 ? '...' : '')
    end
    
    def duplicate_issue_exists?(existing_issues, new_issue)
      existing_issues.any? do |existing|
        # Check for overlapping time ranges and similar kinds
        time_overlap = time_ranges_overlap?(
          [existing[:start_ms], existing[:end_ms]],
          [new_issue[:start_ms], new_issue[:end_ms]]
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
      when 'high' then 1
      when 'medium' then 2
      when 'low' then 3
      else 4
      end
    end
    
    def generate_fallback_coaching_advice(issues)
      # Simple rule-based coaching advice as fallback
      issue_counts = issues.group_by { |i| i[:kind] }.transform_values(&:count)
      top_issue = issue_counts.max_by { |_, count| count }&.first
      
      {
        focus_areas: [
          {
            skill: top_issue || 'general_improvement',
            current_level: determine_user_level,
            target_improvement: 'Reduce frequency by 30%',
            timeline: '1-2 weeks'
          }
        ],
        weekly_goals: [
          {
            goal: "Work on #{top_issue || 'speaking clarity'}",
            strategies: ['Practice daily', 'Record yourself'],
            measurement: 'Track improvement in next session',
            difficulty: 'medium'
          }
        ],
        motivation_message: 'Keep practicing - improvement comes with consistency!'
      }
    end
  end
end