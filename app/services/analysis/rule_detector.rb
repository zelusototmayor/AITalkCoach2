module Analysis
  class RuleDetector
    class DetectionError < StandardError; end
    
    def initialize(transcript_data, language: 'en')
      @transcript_data = transcript_data
      @language = language
      @rules = Rulepacks.load_rules(language)
      @detected_issues = []
    end
    
    def detect_all_issues
      @detected_issues = []

      @rules.each do |category, category_rules|
        # Skip filler_words - AI will handle these from scratch
        next if category == 'filler_words'

        category_rules.each do |rule|
          issues = detect_rule_issues(rule, category)
          @detected_issues.concat(issues)
        end
      end

      Rails.logger.info "RuleDetector: Detected #{@detected_issues.length} non-filler issues (filler detection delegated to AI)"

      # Sort by start time and return
      @detected_issues.sort_by { |issue| issue[:start_ms] }
    end
    
    def detect_category_issues(category)
      category_rules = @rules[category.to_s] || []
      issues = []
      
      category_rules.each do |rule|
        rule_issues = detect_rule_issues(rule, category)
        issues.concat(rule_issues)
      end
      
      issues.sort_by { |issue| issue[:start_ms] }
    end
    
    
    private
    
    def detect_rule_issues(rule, category)
      case rule[:regex]
      when :special_pattern
        detect_special_pattern_issues(rule, category)
      when Regexp
        detect_regex_pattern_issues(rule, category)
      else
        []
      end
    end
    
    def detect_special_pattern_issues(rule, category)
      case rule[:pattern]
      when 'speaking_rate_below_120'
        detect_slow_speaking_rate(rule, category)
      when 'speaking_rate_above_180'
        detect_fast_speaking_rate(rule, category)
      when 'long_pause_over_3s'
        detect_long_pauses(rule, category)
      else
        []
      end
    end
    
    def detect_regex_pattern_issues(rule, category)
      issues = []
      words = @transcript_data[:words] || []
      full_transcript = extract_full_transcript
      
      matches = full_transcript.scan(rule[:regex])
      return issues if matches.empty?
      
      # Find word-level matches for timing
      word_matches = []
      words.each do |word|
        if rule[:regex].match?(word[:punctuated_word] || word[:word])
          word_matches << word
        end
      end
      
      # Group matches by proximity if needed
      grouped_matches = group_nearby_matches(word_matches, rule[:context_window])
      
      grouped_matches.each do |match_group|
        next if match_group.empty?
        
        start_word = match_group.first
        end_word = match_group.last
        
        # Extract surrounding context
        context = extract_context_around_words(start_word, end_word, rule[:context_window])
        
        issue = {
          kind: categorize_issue_kind(category, rule[:pattern]),
          start_ms: start_word[:start],
          end_ms: end_word[:end],
          text: context[:text],
          source: 'rule',
          rationale: rule[:description],
          tip: rule[:tip],
          severity: rule[:severity],
          pattern: rule[:pattern],
          category: category,
          matched_words: match_group.map { |w| w[:punctuated_word] || w[:word] }
        }
        
        issues << issue
      end
      
      # Apply rate limiting if specified
      if rule[:max_matches_per_minute] && issues.length > 0
        duration_minutes = (@transcript_data[:metadata][:duration] / 60.0)
        max_issues = (rule[:max_matches_per_minute] * duration_minutes).ceil
        issues = issues.first(max_issues)
      end
      
      issues
    end
    
    def detect_slow_speaking_rate(rule, category)
      words = extract_words
      duration_ms = @transcript_data[:metadata][:duration] * 1000
      speaking_rate = calculate_speaking_rate(words, duration_ms)

      if speaking_rate < Analysis::Metrics::SLOW_WPM_THRESHOLD
        [{
          kind: 'pace_too_slow',
          start_ms: 0,
          end_ms: duration_ms.to_i,
          text: extract_full_transcript[0..100] + '...',
          source: 'rule',
          rationale: rule[:description],
          tip: rule[:tip],
          severity: rule[:severity],
          category: category,
          speaking_rate: speaking_rate
        }]
      else
        []
      end
    end

    def detect_fast_speaking_rate(rule, category)
      words = extract_words
      duration_ms = @transcript_data[:metadata][:duration] * 1000
      speaking_rate = calculate_speaking_rate(words, duration_ms)

      if speaking_rate > Analysis::Metrics::FAST_WPM_THRESHOLD
        [{
          kind: 'pace_too_fast',
          start_ms: 0,
          end_ms: duration_ms.to_i,
          text: extract_full_transcript[0..100] + '...',
          source: 'rule',
          rationale: rule[:description],
          tip: rule[:tip],
          severity: rule[:severity],
          category: category,
          speaking_rate: speaking_rate
        }]
      else
        []
      end
    end
    
    def detect_long_pauses(rule, category)
      issues = []
      words = @transcript_data[:words] || []
      
      words.each_cons(2) do |current_word, next_word|
        pause_duration_ms = next_word[:start] - current_word[:end]
        
        if pause_duration_ms > 3000 # 3 seconds
          issue = {
            kind: 'long_pause',
            start_ms: current_word[:end],
            end_ms: next_word[:start],
            text: "#{current_word[:punctuated_word]}... [pause: #{pause_duration_ms/1000.0}s] ...#{next_word[:punctuated_word]}",
            source: 'rule',
            rationale: rule[:description],
            tip: rule[:tip],
            severity: rule[:severity],
            category: category,
            pause_duration_ms: pause_duration_ms
          }
          
          issues << issue
        end
      end
      
      issues
    end
    
    def group_nearby_matches(word_matches, context_window)
      return [word_matches] if word_matches.length <= 1
      
      groups = []
      current_group = [word_matches.first]
      
      word_matches.each_cons(2) do |current, next_word|
        time_gap_ms = next_word[:start] - current[:end]
        
        if time_gap_ms <= (context_window * 1000) # Convert to milliseconds
          current_group << next_word
        else
          groups << current_group unless current_group.empty?
          current_group = [next_word]
        end
      end
      
      groups << current_group unless current_group.empty?
      groups
    end
    
    def extract_context_around_words(start_word, end_word, context_window)
      words = @transcript_data[:words] || []
      start_index = words.find_index { |w| w[:start] == start_word[:start] }
      end_index = words.find_index { |w| w[:end] == end_word[:end] }
      
      return { text: start_word[:punctuated_word] || start_word[:word] } unless start_index && end_index
      
      context_start = [start_index - context_window, 0].max
      context_end = [end_index + context_window, words.length - 1].min
      
      context_words = words[context_start..context_end]
      context_text = context_words.map { |w| w[:punctuated_word] || w[:word] }.join(' ')
      
      {
        text: context_text,
        start_ms: context_words.first[:start],
        end_ms: context_words.last[:end]
      }
    end
    
    def categorize_issue_kind(category, pattern)
      case category
      when 'filler_words'
        'filler_word'
      when 'pace_issues'
        'pace_issue'
      when 'clarity_issues'
        'clarity_issue'
      when 'professional_issues'
        'professionalism'
      when 'articulation_issues'
        'articulation'
      when 'repetition_issues'
        'repetition'
      else
        'other'
      end
    end
    
    def extract_full_transcript
      @transcript_data[:transcript] || ''
    end
    
    def extract_words
      @transcript_data[:words] || []
    end
    
    def calculate_speaking_rate(words, duration_ms)
      return 0 if words.empty? || duration_ms <= 0

      # Use speaking time instead of total duration for more accurate assessment
      speaking_time_ms = words.sum { |word| word[:end] - word[:start] }
      return 0 if speaking_time_ms <= 0

      speaking_minutes = speaking_time_ms / 60_000.0
      words.length / speaking_minutes
    end
    
  end
end