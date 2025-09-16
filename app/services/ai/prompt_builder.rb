module Ai
  class PromptBuilder
    class PromptError < StandardError; end
    
    PROMPT_TYPES = %w[
      speech_analysis
      issue_classification
      coaching_advice
      segment_evaluation
      progress_assessment
    ].freeze
    
    def initialize(prompt_type, options = {})
      unless PROMPT_TYPES.include?(prompt_type.to_s)
        raise PromptError, "Invalid prompt type: #{prompt_type}"
      end
      
      @prompt_type = prompt_type.to_s
      @options = options
    end
    
    def build_system_prompt
      case @prompt_type
      when 'speech_analysis'
        build_speech_analysis_system_prompt
      when 'issue_classification'
        build_issue_classification_system_prompt
      when 'coaching_advice'
        build_coaching_advice_system_prompt
      when 'segment_evaluation'
        build_segment_evaluation_system_prompt
      when 'progress_assessment'
        build_progress_assessment_system_prompt
      else
        raise PromptError, "No system prompt defined for: #{@prompt_type}"
      end
    end
    
    def build_user_prompt(data)
      case @prompt_type
      when 'speech_analysis'
        build_speech_analysis_user_prompt(data)
      when 'issue_classification'
        build_issue_classification_user_prompt(data)
      when 'coaching_advice'
        build_coaching_advice_user_prompt(data)
      when 'segment_evaluation'
        build_segment_evaluation_user_prompt(data)
      when 'progress_assessment'
        build_progress_assessment_user_prompt(data)
      else
        raise PromptError, "No user prompt defined for: #{@prompt_type}"
      end
    end
    
    def build_messages(data)
      [
        { role: 'system', content: build_system_prompt },
        { role: 'user', content: build_user_prompt(data) }
      ]
    end
    
    def expected_json_schema
      case @prompt_type
      when 'speech_analysis'
        speech_analysis_json_schema
      when 'issue_classification'
        issue_classification_json_schema
      when 'coaching_advice'
        coaching_advice_json_schema
      when 'segment_evaluation'
        segment_evaluation_json_schema
      when 'progress_assessment'
        progress_assessment_json_schema
      else
        {}
      end
    end
    
    private
    
    def build_speech_analysis_system_prompt
      language = @options[:language] || 'en'
      target_audience = @options[:target_audience] || 'general'
      
      <<~PROMPT
        You are an expert speech coach specializing in #{language} communication analysis. 
        Your role is to analyze speech segments for a #{target_audience} audience and provide constructive feedback.
        
        Focus on these key areas:
        1. **Clarity & Articulation**: Word pronunciation, enunciation, speech rate
        2. **Professional Language**: Word choice, grammar, appropriateness
        3. **Confidence & Presence**: Voice projection, hesitation patterns, assertiveness
        4. **Engagement**: Energy level, variation in pace/tone, audience connection
        5. **Structure & Flow**: Logical progression, transitions, coherence
        
        Important analysis guidelines:
        - Be constructive and encouraging while being specific about improvements
        - Provide confidence scores (0.0-1.0) for each identified issue
        - Focus on 3-5 most impactful improvements rather than listing every minor issue
        - Consider the context and purpose of the speech when making assessments
        - Provide actionable, specific recommendations
        
        CRITICAL: You must respond with valid JSON only. No additional text, explanations, or formatting.
        
        The JSON structure must be:
        {
          "overall_assessment": {
            "clarity_score": 85,
            "confidence_score": 78,
            "engagement_score": 92,
            "professionalism_score": 88,
            "overall_score": 86
          },
          "strengths": [
            "Clear articulation throughout",
            "Strong voice projection"
          ],
          "improvement_areas": [
            {
              "category": "pace",
              "issue": "Speaking too quickly in middle section",
              "confidence": 0.8,
              "severity": "medium",
              "specific_recommendation": "Practice with metronome at 140-160 WPM",
              "priority": "high"
            }
          ],
          "coaching_insights": [
            "Consider using more strategic pauses for emphasis",
            "Vary your pace to match content importance"
          ]
        }
      PROMPT
    end
    
    def build_speech_analysis_user_prompt(data)
      transcript = data[:transcript] || data[:text]
      context = data[:context] || {}
      
      prompt = "Analyze this speech segment:\n\n"
      prompt += "**Transcript:**\n\"#{transcript}\"\n\n"
      
      if context[:duration_seconds]
        prompt += "**Duration:** #{context[:duration_seconds]} seconds\n"
      end
      
      if context[:word_count]
        prompt += "**Word Count:** #{context[:word_count]} words\n"
      end
      
      if context[:speech_type]
        prompt += "**Speech Type:** #{context[:speech_type]}\n"
      end
      
      if context[:target_audience]
        prompt += "**Target Audience:** #{context[:target_audience]}\n"
      end
      
      if data[:detected_issues]&.any?
        prompt += "\n**Pre-detected Issues (for context):**\n"
        data[:detected_issues].each do |issue|
          prompt += "- #{issue[:kind]}: #{issue[:text]} (severity: #{issue[:severity]})\n"
        end
      end
      
      prompt += "\nProvide your analysis in the specified JSON format."
    end
    
    def build_issue_classification_system_prompt
      <<~PROMPT
        You are a speech pattern classifier with expertise in identifying and validating communication issues.
        
        Your task is to review detected speech patterns and:
        1. Validate if they are genuinely problematic
        2. Assess the confidence level of each detection
        3. Determine appropriate severity levels
        4. Provide specific, actionable coaching recommendations
        5. Prioritize issues based on impact and user level
        
        Classification Guidelines:
        - **Confidence (0.0-1.0)**: How certain you are this is actually an issue
        - **Severity**: low (minor impact), medium (noticeable impact), high (significant impact)
        - **Priority**: low (address later), medium (address soon), high (address immediately)
        
        Consider user experience level when making recommendations:
        - Beginners: Focus on 1-2 fundamental issues, gentle guidance
        - Intermediate: Address 3-4 issues with specific techniques
        - Advanced: Provide nuanced feedback on subtle patterns
        
        CRITICAL: Return only valid JSON, no additional text.
        
        Expected JSON structure:
        {
          "validated_issues": [
            {
              "original_detection": "filler_word",
              "validation": "confirmed",
              "confidence": 0.9,
              "severity": "medium",
              "impact_description": "Disrupts flow and reduces perceived confidence",
              "coaching_recommendation": "Practice the 'pause and breathe' technique",
              "priority": "high",
              "practice_exercise": "Record 5-minute sessions focusing on eliminating 'um'"
            }
          ],
          "false_positives": [
            {
              "original_detection": "pace_too_fast",
              "reason": "Natural speaking rate for this content type",
              "confidence_override": 0.2
            }
          ],
          "summary": {
            "total_valid_issues": 4,
            "high_priority_count": 1,
            "medium_priority_count": 2,
            "low_priority_count": 1,
            "recommended_focus": "Start with filler word reduction"
          }
        }
      PROMPT
    end
    
    def build_issue_classification_user_prompt(data)
      issues = data[:issues] || []
      context = data[:context] || {}
      
      prompt = "Please validate and classify these detected speech issues:\n\n"
      
      issues.each_with_index do |issue, index|
        prompt += "**Issue #{index + 1}:**\n"
        prompt += "- Type: #{issue[:kind]}\n"
        prompt += "- Detected text: \"#{issue[:text]}\"\n"
        prompt += "- Current severity: #{issue[:severity]}\n"
        prompt += "- Detection rationale: #{issue[:rationale]}\n"
        prompt += "- Time range: #{issue[:start_ms]/1000.0}s - #{issue[:end_ms]/1000.0}s\n\n"
      end
      
      if context[:user_level]
        prompt += "**User Experience Level:** #{context[:user_level]}\n"
      end
      
      if context[:session_count]
        prompt += "**Session Count:** #{context[:session_count]} sessions completed\n"
      end
      
      if context[:previous_issues]
        prompt += "**Recurring Issues:** #{context[:previous_issues].join(', ')}\n"
      end
      
      prompt += "\nValidate each detection and provide classification in the specified JSON format."
    end
    
    def build_coaching_advice_system_prompt
      coaching_style = @options[:coaching_style] || 'supportive'
      
      <<~PROMPT
        You are a personalized speech coach with a #{coaching_style} approach. Create individualized coaching plans based on user progress and patterns.
        
        Your coaching philosophy:
        - Build on existing strengths while addressing weaknesses
        - Provide progressive skill development (don't overwhelm)
        - Use specific, measurable goals with clear success metrics
        - Maintain encouragement while being honest about areas for improvement
        - Adapt recommendations to user's experience level and goals
        
        Coaching Components:
        1. **Focus Areas**: 2-3 primary skills to work on (based on data patterns)
        2. **Weekly Goals**: Specific, measurable objectives for the next 7 days
        3. **Practice Exercises**: Concrete activities with time commitments
        4. **Progress Tracking**: How to measure improvement
        5. **Motivation**: Acknowledge progress and build confidence
        
        CRITICAL: Respond only with valid JSON, no additional text.
        
        Expected JSON format:
        {
          "focus_areas": [
            {
              "skill": "pace_control",
              "current_level": "beginner",
              "target_improvement": "20% reduction in speed variation",
              "timeline": "2 weeks"
            }
          ],
          "weekly_goals": [
            {
              "goal": "Reduce filler words from 5 per minute to 2 per minute",
              "strategies": ["Count to 2 before speaking", "Practice with transcript"],
              "measurement": "Track filler count in daily 5-minute recordings",
              "difficulty": "medium"
            }
          ],
          "practice_plan": [
            {
              "exercise": "Mirror speaking practice",
              "duration": "10 minutes",
              "frequency": "daily",
              "focus": "Observe and control facial expressions",
              "week": 1
            }
          ],
          "progress_acknowledgment": {
            "recent_improvements": ["25% reduction in long pauses"],
            "consistency_praise": "Completed 6 out of 7 practice sessions last week",
            "next_milestone": "Target: 80+ clarity score consistently"
          },
          "motivation_message": "Your speaking confidence has noticeably improved! Focus on pace consistency next."
        }
      PROMPT
    end
    
    def build_coaching_advice_user_prompt(data)
      user_profile = data[:user_profile] || {}
      recent_sessions = data[:recent_sessions] || []
      issue_trends = data[:issue_trends] || {}
      
      prompt = "Create personalized coaching advice for this user:\n\n"
      
      prompt += "**User Profile:**\n"
      prompt += "- Total sessions: #{user_profile[:session_count] || 0}\n"
      prompt += "- Experience level: #{user_profile[:level] || 'beginner'}\n"
      prompt += "- Primary goals: #{(user_profile[:goals] || []).join(', ')}\n"
      prompt += "- Preferred practice time: #{user_profile[:practice_time] || '10-15 minutes'}\n\n"
      
      if recent_sessions.any?
        prompt += "**Recent Session Performance:**\n"
        recent_sessions.each_with_index do |session, index|
          prompt += "Session #{index + 1} (#{session[:date]}):\n"
          prompt += "- Overall score: #{session[:overall_score]}/100\n"
          prompt += "- Top issues: #{session[:top_issues]&.join(', ')}\n"
          prompt += "- Duration: #{session[:duration_seconds]} seconds\n\n"
        end
      end
      
      if issue_trends.any?
        prompt += "**Issue Trends (Last 30 days):**\n"
        issue_trends.each do |issue_type, data|
          prompt += "- #{issue_type}: #{data[:count]} occurrences, "
          prompt += "#{data[:trend]} trend (#{data[:change_percentage]}%)\n"
        end
        prompt += "\n"
      end
      
      prompt += "Based on this data, create a personalized coaching plan in the specified JSON format."
    end
    
    def build_segment_evaluation_system_prompt
      <<~PROMPT
        You are a speech segment evaluator specializing in identifying the most valuable segments for detailed analysis.
        
        Your task is to assess speech segments and determine:
        1. **Educational Value**: How much can the user learn from analyzing this segment?
        2. **Issue Density**: Are there meaningful patterns or problems to address?
        3. **Representativeness**: Does this segment reflect typical speaking patterns?
        4. **Coaching Potential**: Can specific, actionable advice be provided?
        
        Evaluation Criteria:
        - High value: Multiple learnable issues, clear improvement opportunities
        - Medium value: Some issues present, moderate learning potential
        - Low value: Few issues, limited coaching opportunities
        
        CRITICAL: Return only valid JSON, no additional text.
        
        Expected JSON structure:
        {
          "evaluation": {
            "educational_value": 0.8,
            "issue_density": 0.7,
            "representativeness": 0.9,
            "coaching_potential": 0.85,
            "overall_score": 0.82
          },
          "key_learning_opportunities": [
            "Pace variation patterns",
            "Professional language usage"
          ],
          "recommended_for_ai_analysis": true,
          "analysis_focus_areas": [
            "pace_control",
            "filler_word_reduction"
          ],
          "segment_summary": "High-energy presentation segment with clear coaching opportunities"
        }
      PROMPT
    end
    
    def build_segment_evaluation_user_prompt(data)
      segment = data[:segment]
      context = data[:context] || {}
      
      prompt = "Evaluate this speech segment for AI analysis potential:\n\n"
      prompt += "**Segment Text:**\n\"#{segment[:text]}\"\n\n"
      prompt += "**Segment Details:**\n"
      prompt += "- Duration: #{segment[:duration_ms]/1000.0} seconds\n"
      prompt += "- Word count: #{segment[:word_count]}\n"
      prompt += "- Time range: #{segment[:start_ms]/1000.0}s - #{segment[:end_ms]/1000.0}s\n\n"
      
      if segment[:quality_score]
        prompt += "- Quality score: #{segment[:quality_score]}\n"
      end
      
      if segment[:speaking_rate]
        prompt += "- Speaking rate: #{segment[:speaking_rate]} WPM\n"
      end
      
      if data[:related_issues]&.any?
        prompt += "\n**Related Rule-Based Issues:**\n"
        data[:related_issues].each do |issue|
          prompt += "- #{issue[:kind]}: #{issue[:severity]} severity\n"
        end
      end
      
      if context[:session_context]
        prompt += "\n**Session Context:**\n"
        prompt += "- Total session duration: #{context[:session_context][:total_duration]}s\n"
        prompt += "- User level: #{context[:session_context][:user_level]}\n"
      end
      
      prompt += "\nEvaluate this segment's potential for AI analysis in the specified JSON format."
    end
    
    def build_progress_assessment_system_prompt
      <<~PROMPT
        You are a progress assessment specialist focused on tracking speech improvement over time.
        
        Your role is to:
        1. Compare current performance against historical data
        2. Identify improvement trends and persistent challenges
        3. Assess goal achievement and set new targets
        4. Provide motivational feedback based on progress
        
        Assessment Framework:
        - **Improvement Rate**: Quantify changes in key metrics
        - **Consistency**: Evaluate performance stability
        - **Skill Development**: Track growth in specific areas
        - **Challenge Areas**: Identify persistent issues needing focus
        
        CRITICAL: Return only valid JSON, no additional text.
        
        Expected JSON structure:
        {
          "progress_summary": {
            "overall_improvement": 0.23,
            "consistency_score": 0.78,
            "sessions_analyzed": 15,
            "time_period_days": 30
          },
          "metric_improvements": [
            {
              "metric": "clarity_score",
              "baseline": 72,
              "current": 84,
              "improvement_percentage": 16.7,
              "trend": "improving"
            }
          ],
          "achievement_status": [
            {
              "goal": "Reduce filler words to under 3 per minute",
              "target": 3.0,
              "current": 2.1,
              "status": "achieved",
              "achievement_date": "2024-01-15"
            }
          ],
          "persistent_challenges": [
            {
              "challenge": "pace_consistency",
              "sessions_affected": 12,
              "severity_trend": "stable",
              "recommended_action": "Focus on metronome practice"
            }
          ],
          "next_focus_recommendations": [
            "Advanced pace variation techniques",
            "Professional presentation skills"
          ],
          "motivation_insights": {
            "biggest_win": "Filler word reduction goal achieved 2 weeks early",
            "improvement_streak": "5 consecutive sessions with 80+ scores",
            "next_milestone": "Maintain 85+ clarity score for 2 weeks"
          }
        }
      PROMPT
    end
    
    def build_progress_assessment_user_prompt(data)
      historical_data = data[:historical_sessions] || []
      current_session = data[:current_session]
      goals = data[:goals] || []
      
      prompt = "Assess progress for this user based on their session history:\n\n"
      
      if current_session
        prompt += "**Current Session:**\n"
        prompt += "- Date: #{current_session[:date]}\n"
        prompt += "- Overall score: #{current_session[:overall_score]}/100\n"
        prompt += "- Key metrics: #{current_session[:metrics]}\n\n"
      end
      
      if historical_data.any?
        prompt += "**Historical Performance (Last #{historical_data.length} sessions):**\n"
        historical_data.each_with_index do |session, index|
          prompt += "Session #{index + 1} (#{session[:date]}): "
          prompt += "Score #{session[:overall_score]}/100, "
          prompt += "Issues: #{session[:issue_count]}\n"
        end
        prompt += "\n"
      end
      
      if goals.any?
        prompt += "**Current Goals:**\n"
        goals.each do |goal|
          prompt += "- #{goal[:description]} (Target: #{goal[:target_value]})\n"
        end
        prompt += "\n"
      end
      
      prompt += "Assess the user's progress and provide insights in the specified JSON format."
    end
    
    # JSON Schema definitions for validation
    
    def speech_analysis_json_schema
      {
        type: 'object',
        required: %w[overall_assessment strengths improvement_areas coaching_insights],
        properties: {
          overall_assessment: {
            type: 'object',
            required: %w[overall_score],
            properties: {
              clarity_score: { type: 'integer', minimum: 0, maximum: 100 },
              confidence_score: { type: 'integer', minimum: 0, maximum: 100 },
              engagement_score: { type: 'integer', minimum: 0, maximum: 100 },
              professionalism_score: { type: 'integer', minimum: 0, maximum: 100 },
              overall_score: { type: 'integer', minimum: 0, maximum: 100 }
            }
          },
          strengths: { type: 'array', items: { type: 'string' } },
          improvement_areas: {
            type: 'array',
            items: {
              type: 'object',
              required: %w[category issue confidence severity priority],
              properties: {
                category: { type: 'string' },
                issue: { type: 'string' },
                confidence: { type: 'number', minimum: 0, maximum: 1 },
                severity: { enum: %w[low medium high] },
                specific_recommendation: { type: 'string' },
                priority: { enum: %w[low medium high] }
              }
            }
          },
          coaching_insights: { type: 'array', items: { type: 'string' } }
        }
      }
    end
    
    def issue_classification_json_schema
      {
        type: 'object',
        required: %w[validated_issues summary],
        properties: {
          validated_issues: { type: 'array' },
          false_positives: { type: 'array' },
          summary: {
            type: 'object',
            required: %w[total_valid_issues],
            properties: {
              total_valid_issues: { type: 'integer', minimum: 0 },
              high_priority_count: { type: 'integer', minimum: 0 },
              medium_priority_count: { type: 'integer', minimum: 0 },
              low_priority_count: { type: 'integer', minimum: 0 }
            }
          }
        }
      }
    end
    
    def coaching_advice_json_schema
      {
        type: 'object',
        required: %w[focus_areas weekly_goals],
        properties: {
          focus_areas: { type: 'array' },
          weekly_goals: { type: 'array' },
          practice_plan: { type: 'array' },
          progress_acknowledgment: { type: 'object' },
          motivation_message: { type: 'string' }
        }
      }
    end
    
    def segment_evaluation_json_schema
      {
        type: 'object',
        required: %w[evaluation recommended_for_ai_analysis],
        properties: {
          evaluation: {
            type: 'object',
            required: %w[overall_score],
            properties: {
              educational_value: { type: 'number', minimum: 0, maximum: 1 },
              issue_density: { type: 'number', minimum: 0, maximum: 1 },
              representativeness: { type: 'number', minimum: 0, maximum: 1 },
              coaching_potential: { type: 'number', minimum: 0, maximum: 1 },
              overall_score: { type: 'number', minimum: 0, maximum: 1 }
            }
          },
          recommended_for_ai_analysis: { type: 'boolean' }
        }
      }
    end
    
    def progress_assessment_json_schema
      {
        type: 'object',
        required: %w[progress_summary metric_improvements],
        properties: {
          progress_summary: {
            type: 'object',
            properties: {
              overall_improvement: { type: 'number' },
              sessions_analyzed: { type: 'integer', minimum: 0 }
            }
          },
          metric_improvements: { type: 'array' },
          achievement_status: { type: 'array' },
          motivation_insights: { type: 'object' }
        }
      }
    end
  end
end