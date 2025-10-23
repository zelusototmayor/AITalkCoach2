module Ai
  class PromptBuilder
    class PromptError < StandardError; end
    
    PROMPT_TYPES = %w[
      speech_analysis
      issue_classification
      coaching_advice
      segment_evaluation
      progress_assessment
      filler_word_detection
      comprehensive_speech_analysis
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
      when 'filler_word_detection'
        build_filler_word_detection_system_prompt
      when 'comprehensive_speech_analysis'
        build_comprehensive_speech_analysis_system_prompt
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
      when 'filler_word_detection'
        build_filler_word_detection_user_prompt(data)
      when 'comprehensive_speech_analysis'
        build_comprehensive_speech_analysis_user_prompt(data)
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

    # Public method for function calling (tools API)
    def tool_schema
      expected_json_schema
    end

    # Expose prompt type for function naming
    def prompt_type
      @prompt_type
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
      when 'filler_word_detection'
        filler_word_detection_json_schema
      when 'comprehensive_speech_analysis'
        comprehensive_speech_analysis_json_schema
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
              "practice_exercise": "Record 5-minute sessions focusing on eliminating 'um'",
              "context_text": "I think, um, we should proceed"
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

        **IMPORTANT - Pattern-Specific Coaching (Phase 3):**
        When you receive 'current_session_insights' with detailed patterns, use them to:

        1. **Identify Specific Moments** (not just overall scores)
           - Example: Instead of "Your pace needs work (65/100)"
           - Say: "I notice you rush in the middle of sessions (pace jumps from 130 to 180 WPM)"

        2. **Create Targeted Exercises** based on patterns
           - If hesitations occur "mostly at sentence starts", recommend practicing opening phrases
           - If pauses are "mostly good with 5 awkward long pauses", focus on reducing those specific pauses
           - If energy is "flat throughout", suggest vocal variation exercises

        3. **Acknowledge Micro-Wins** in specific areas
           - Example: "Your word pacing is excellent (85/100) - you're smooth once you get going!"
           - This builds confidence while addressing areas for improvement

        4. **Use Pattern Data** to make advice actionable
           - "You say 'um' mostly at sentence starts (6 out of 8 times)" → Practice prepared openings
           - "Pace trajectory: starts slow, rushes middle, settles" → Focus on mid-session awareness

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
      current_session_insights = data[:current_session_insights] || {}

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

      # Phase 3: Add current session insights for pattern-specific coaching
      if current_session_insights[:standout_patterns]&.any? || current_session_insights[:micro_opportunities]&.any?
        prompt += "**Current Session Patterns (Use these for specific, actionable advice!):**\n"

        if current_session_insights[:standout_patterns]&.any?
          prompt += "\nStandout Patterns:\n"
          current_session_insights[:standout_patterns].each do |pattern|
            prompt += "- #{pattern}\n"
          end
        end

        if current_session_insights[:micro_opportunities]&.any?
          prompt += "\nMicro-Opportunities (strengths to acknowledge):\n"
          current_session_insights[:micro_opportunities].each do |opportunity|
            if opportunity.is_a?(Hash)
              prompt += "- #{opportunity[:type]}: #{opportunity[:insight] || opportunity[:pattern]}\n"
              prompt += "  Suggestion: #{opportunity[:suggestion]}\n"
            else
              prompt += "- #{opportunity}\n"
            end
          end
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
            required: %w[clarity_score confidence_score engagement_score professionalism_score overall_score],
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
              required: %w[category issue confidence severity specific_recommendation priority],
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
        required: %w[validated_issues false_positives summary],
        properties: {
          validated_issues: {
            type: 'array',
            items: {
              type: 'object',
              required: %w[original_detection validation confidence severity impact_description coaching_recommendation priority practice_exercise context_text],
              properties: {
                original_detection: { type: 'string' },
                validation: { type: 'string' },
                confidence: { type: 'number', minimum: 0, maximum: 1 },
                severity: { enum: %w[low medium high] },
                impact_description: { type: 'string' },
                coaching_recommendation: { type: 'string' },
                priority: { enum: %w[low medium high] },
                practice_exercise: { type: 'string' },
                context_text: { type: 'string' }
              }
            }
          },
          false_positives: {
            type: 'array',
            items: {
              type: 'object',
              required: %w[original_detection reason confidence_override],
              properties: {
                original_detection: { type: 'string' },
                reason: { type: 'string' },
                confidence_override: { type: 'number', minimum: 0, maximum: 1 }
              }
            }
          },
          summary: {
            type: 'object',
            required: %w[total_valid_issues high_priority_count medium_priority_count low_priority_count recommended_focus],
            properties: {
              total_valid_issues: { type: 'integer', minimum: 0 },
              high_priority_count: { type: 'integer', minimum: 0 },
              medium_priority_count: { type: 'integer', minimum: 0 },
              low_priority_count: { type: 'integer', minimum: 0 },
              recommended_focus: { type: 'string' }
            }
          }
        }
      }
    end
    
    def coaching_advice_json_schema
      {
        type: 'object',
        required: %w[focus_areas weekly_goals practice_plan progress_acknowledgment motivation_message],
        properties: {
          focus_areas: {
            type: 'array',
            items: {
              type: 'object',
              required: %w[skill current_level target_improvement timeline],
              properties: {
                skill: { type: 'string' },
                current_level: { type: 'string' },
                target_improvement: { type: 'string' },
                timeline: { type: 'string' }
              }
            }
          },
          weekly_goals: {
            type: 'array',
            items: {
              type: 'object',
              required: %w[goal strategies measurement difficulty],
              properties: {
                goal: { type: 'string' },
                strategies: { type: 'array', items: { type: 'string' } },
                measurement: { type: 'string' },
                difficulty: { type: 'string' }
              }
            }
          },
          practice_plan: {
            type: 'array',
            items: {
              type: 'object',
              required: %w[exercise duration frequency focus week],
              properties: {
                exercise: { type: 'string' },
                duration: { type: 'string' },
                frequency: { type: 'string' },
                focus: { type: 'string' },
                week: { type: 'integer', minimum: 1 }
              }
            }
          },
          progress_acknowledgment: {
            type: 'object',
            required: %w[recent_improvements consistency_praise next_milestone],
            properties: {
              recent_improvements: { type: 'array', items: { type: 'string' } },
              consistency_praise: { type: 'string' },
              next_milestone: { type: 'string' }
            }
          },
          motivation_message: { type: 'string' }
        }
      }
    end
    
    def segment_evaluation_json_schema
      {
        type: 'object',
        required: %w[evaluation key_learning_opportunities recommended_for_ai_analysis analysis_focus_areas segment_summary],
        properties: {
          evaluation: {
            type: 'object',
            required: %w[educational_value issue_density representativeness coaching_potential overall_score],
            properties: {
              educational_value: { type: 'number', minimum: 0, maximum: 1 },
              issue_density: { type: 'number', minimum: 0, maximum: 1 },
              representativeness: { type: 'number', minimum: 0, maximum: 1 },
              coaching_potential: { type: 'number', minimum: 0, maximum: 1 },
              overall_score: { type: 'number', minimum: 0, maximum: 1 }
            }
          },
          key_learning_opportunities: {
            type: 'array',
            items: { type: 'string' }
          },
          recommended_for_ai_analysis: { type: 'boolean' },
          analysis_focus_areas: {
            type: 'array',
            items: { type: 'string' }
          },
          segment_summary: { type: 'string' }
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
              consistency_score: { type: 'number' },
              sessions_analyzed: { type: 'integer', minimum: 0 },
              time_period_days: { type: 'integer', minimum: 0 }
            }
          },
          metric_improvements: {
            type: 'array',
            items: {
              type: 'object',
              required: %w[metric baseline current improvement_percentage trend],
              properties: {
                metric: { type: 'string' },
                baseline: { type: 'number' },
                current: { type: 'number' },
                improvement_percentage: { type: 'number' },
                trend: { type: 'string' }
              }
            }
          },
          achievement_status: {
            type: 'array',
            items: {
              type: 'object',
              required: %w[goal target current status achievement_date],
              properties: {
                goal: { type: 'string' },
                target: { type: 'number' },
                current: { type: 'number' },
                status: { type: 'string' },
                achievement_date: { type: 'string' }
              }
            }
          },
          persistent_challenges: {
            type: 'array',
            items: {
              type: 'object',
              required: %w[challenge sessions_affected severity_trend recommended_action],
              properties: {
                challenge: { type: 'string' },
                sessions_affected: { type: 'integer', minimum: 0 },
                severity_trend: { type: 'string' },
                recommended_action: { type: 'string' }
              }
            }
          },
          next_focus_recommendations: {
            type: 'array',
            items: { type: 'string' }
          },
          motivation_insights: {
            type: 'object',
            required: %w[biggest_win improvement_streak next_milestone],
            properties: {
              biggest_win: { type: 'string' },
              improvement_streak: { type: 'string' },
              next_milestone: { type: 'string' }
            }
          }
        }
      }
    end
    def build_filler_word_detection_system_prompt
      language = @options[:language] || 'en'

      <<~PROMPT
        You are an expert speech coach analyzing filler word usage in #{language}.

        Identify all words and phrases being used as verbal crutches or fillers - these weaken the speaker's message and should be reduced or eliminated.

        **Key principle:** Only flag words when they function as fillers, not when they serve a legitimate purpose.
        - "like" in "I like pizza" = legitimate (preference)
        - "like" in "it's, like, really good" = filler (verbal crutch)

        Be thorough and context-aware. Common fillers include: um, uh, like, so, you know, I mean, basically, actually, kind of, sort of, just, right, well, okay, now, and phrases like "you see", "at the end of the day", etc.

        For each filler detected, provide:
        - The filler word/phrase
        - Surrounding text snippet (10-15 words of context)
        - Confidence score (0.0-1.0)
        - Brief rationale explaining why it's a filler
        - Severity (low/medium/high) based on frequency and impact

        Return ONLY valid JSON in this exact structure:
        {
          "filler_words": [
            {
              "word": "um",
              "text_snippet": "I think, um, we should proceed carefully",
              "start_ms": 1500,
              "confidence": 0.95,
              "rationale": "Hesitation filler disrupting sentence flow",
              "severity": "medium"
            }
          ],
          "summary": {
            "total_detected": 8,
            "filler_rate_per_minute": 4.2,
            "most_common_fillers": ["um", "like", "so"],
            "recommendation": "Focus on replacing 'um' with strategic pauses"
          }
        }
      PROMPT
    end

    def build_filler_word_detection_user_prompt(data)
      transcript = data[:transcript] || ''
      context = data[:context] || {}

      prompt = "Analyze this transcript for filler words:\n\n"
      prompt += "\"#{transcript}\"\n\n"

      if context[:duration_seconds]
        prompt += "Duration: #{context[:duration_seconds].round(1)} seconds\n"
      end

      if context[:word_count]
        prompt += "Word count: #{context[:word_count]}\n"
      end

      prompt += "\nIdentify ALL filler words. Return only the JSON response."
    end

    def filler_word_detection_json_schema
      {
        type: 'object',
        required: %w[filler_words summary],
        properties: {
          filler_words: {
            type: 'array',
            items: {
              type: 'object',
              required: %w[word text_snippet start_ms confidence rationale severity],
              properties: {
                word: { type: 'string' },
                text_snippet: { type: 'string' },
                start_ms: { type: 'integer', minimum: 0 },
                confidence: { type: 'number', minimum: 0, maximum: 1 },
                rationale: { type: 'string' },
                severity: { enum: %w[low medium high] }
              }
            }
          },
          summary: {
            type: 'object',
            required: %w[total_detected filler_rate_per_minute most_common_fillers recommendation],
            properties: {
              total_detected: { type: 'integer', minimum: 0 },
              filler_rate_per_minute: { type: 'number', minimum: 0 },
              most_common_fillers: { type: 'array', items: { type: 'string' } },
              recommendation: { type: 'string' }
            }
          }
        }
      }
    end

    # Comprehensive Speech Analysis - Combines filler detection + issue classification
    def build_comprehensive_speech_analysis_system_prompt
      language = @options[:language] || 'en'

      <<~PROMPT
        You are an expert speech coach performing comprehensive analysis of #{language} communication.

        Your task is to analyze the full transcript and provide:
        1. **Filler Word Detection**: Identify ALL words/phrases used as verbal crutches
        2. **Issue Validation**: Validate rule-based detections and assess severity
        3. **Speech Quality Assessment**: Evaluate overall speaking quality

        ## Filler Word Detection Guidelines

        **Key principle:** Only flag words when they function as fillers, not when they serve a legitimate purpose.
        - "like" in "I like pizza" = legitimate (preference)
        - "like" in "it's, like, really good" = filler (verbal crutch)

        Common fillers: um, uh, like, so, you know, I mean, basically, actually, kind of, sort of, just, right, well, okay, now

        ## Issue Validation Guidelines

        Review rule-based detections and:
        - Confirm if genuinely problematic
        - Assess confidence level (0.0-1.0)
        - Determine severity (low/medium/high)
        - Provide coaching recommendations
        - Identify false positives

        ## Response Format

        Return ONLY valid JSON with this exact structure:
        {
          "filler_words": [
            {
              "word": "um",
              "text_snippet": "I think, um, we should proceed carefully",
              "start_ms": 1500,
              "confidence": 0.95,
              "rationale": "Hesitation filler disrupting sentence flow",
              "severity": "medium"
            }
          ],
          "validated_issues": [
            {
              "original_detection": "professionalism",
              "validation": "confirmed",
              "confidence": 0.85,
              "severity": "medium",
              "impact_description": "Casual language reduces professional tone",
              "coaching_recommendation": "Replace casual phrases with formal alternatives",
              "priority": "medium",
              "practice_exercise": "Record yourself reading professional texts",
              "context_text": "yeah, we should probably do that"
            }
          ],
          "false_positives": [
            {
              "original_detection": "pace_too_fast",
              "reason": "Natural conversational pace for this content type",
              "confidence_override": 0.2
            }
          ],
          "speech_quality": {
            "overall_clarity": 0.85,
            "overall_fluency": 0.78,
            "pacing_quality": 0.72,
            "engagement_level": 0.80,
            "key_strengths": ["Clear articulation", "Good voice projection"],
            "primary_concern": "Moderate filler word usage affects flow"
          },
          "summary": {
            "total_filler_count": 8,
            "filler_rate_per_minute": 4.2,
            "most_common_fillers": ["um", "like"],
            "total_valid_issues": 3,
            "high_priority_count": 1,
            "medium_priority_count": 1,
            "low_priority_count": 1,
            "recommended_focus": "Reduce filler words and increase pace variation",
            "filler_recommendation": "Focus on replacing 'um' with strategic pauses"
          }
        }
      PROMPT
    end

    def build_comprehensive_speech_analysis_user_prompt(data)
      transcript = data[:transcript] || ''
      rule_issues = data[:rule_issues] || []
      context = data[:context] || {}

      prompt = "Perform comprehensive analysis on this speech:\n\n"
      prompt += "**Full Transcript:**\n\"#{transcript}\"\n\n"

      if context[:duration_seconds]
        prompt += "**Duration:** #{context[:duration_seconds].round(1)} seconds\n"
      end

      if context[:word_count]
        prompt += "**Word Count:** #{context[:word_count]} words\n"
      end

      if context[:user_level]
        prompt += "**Speaker Level:** #{context[:user_level]}\n"
      end

      # Include rule-based detections for validation
      if rule_issues.any?
        prompt += "\n**Rule-Based Detections to Validate:**\n"
        rule_issues.each_with_index do |issue, index|
          prompt += "\n#{index + 1}. **#{issue[:kind]}**\n"
          prompt += "   - Text: \"#{issue[:text]}\"\n"
          prompt += "   - Detected severity: #{issue[:severity]}\n"
          prompt += "   - Rationale: #{issue[:rationale]}\n"
          prompt += "   - Time: #{issue[:start_ms]/1000.0}s - #{issue[:end_ms]/1000.0}s\n"
        end
      else
        prompt += "\n**No rule-based issues detected** - perform fresh analysis for all issue types.\n"
      end

      prompt += "\n\nAnalyze the transcript comprehensively. Detect ALL filler words and validate rule-based issues. Return only the JSON response."
    end

    def comprehensive_speech_analysis_json_schema
      {
        type: 'object',
        required: %w[filler_words validated_issues false_positives speech_quality summary],
        properties: {
          filler_words: {
            type: 'array',
            items: {
              type: 'object',
              required: %w[word text_snippet start_ms confidence rationale severity],
              properties: {
                word: { type: 'string' },
                text_snippet: { type: 'string' },
                start_ms: { type: 'integer', minimum: 0 },
                confidence: { type: 'number', minimum: 0, maximum: 1 },
                rationale: { type: 'string' },
                severity: { enum: %w[low medium high] }
              }
            }
          },
          validated_issues: {
            type: 'array',
            items: {
              type: 'object',
              required: %w[original_detection validation confidence severity impact_description coaching_recommendation priority practice_exercise context_text],
              properties: {
                original_detection: { type: 'string' },
                validation: { type: 'string' },
                confidence: { type: 'number', minimum: 0, maximum: 1 },
                severity: { enum: %w[low medium high] },
                impact_description: { type: 'string' },
                coaching_recommendation: { type: 'string' },
                priority: { enum: %w[low medium high] },
                practice_exercise: { type: 'string' },
                context_text: { type: 'string' }
              }
            }
          },
          false_positives: {
            type: 'array',
            items: {
              type: 'object',
              required: %w[original_detection reason confidence_override],
              properties: {
                original_detection: { type: 'string' },
                reason: { type: 'string' },
                confidence_override: { type: 'number', minimum: 0, maximum: 1 }
              }
            }
          },
          speech_quality: {
            type: 'object',
            required: %w[overall_clarity overall_fluency pacing_quality engagement_level key_strengths primary_concern],
            properties: {
              overall_clarity: { type: 'number', minimum: 0, maximum: 1 },
              overall_fluency: { type: 'number', minimum: 0, maximum: 1 },
              pacing_quality: { type: 'number', minimum: 0, maximum: 1 },
              engagement_level: { type: 'number', minimum: 0, maximum: 1 },
              key_strengths: { type: 'array', items: { type: 'string' } },
              primary_concern: { type: 'string' }
            }
          },
          summary: {
            type: 'object',
            required: %w[total_filler_count filler_rate_per_minute most_common_fillers total_valid_issues high_priority_count medium_priority_count low_priority_count recommended_focus filler_recommendation],
            properties: {
              total_filler_count: { type: 'integer', minimum: 0 },
              filler_rate_per_minute: { type: 'number', minimum: 0 },
              most_common_fillers: { type: 'array', items: { type: 'string' } },
              total_valid_issues: { type: 'integer', minimum: 0 },
              high_priority_count: { type: 'integer', minimum: 0 },
              medium_priority_count: { type: 'integer', minimum: 0 },
              low_priority_count: { type: 'integer', minimum: 0 },
              recommended_focus: { type: 'string' },
              filler_recommendation: { type: 'string' }
            }
          }
        }
      }
    end
  end
end