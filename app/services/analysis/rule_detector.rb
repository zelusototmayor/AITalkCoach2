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
        category_rules.each do |rule|
          issues = detect_rule_issues(rule, category)
          @detected_issues.concat(issues)
        end
      end
      
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
    
    def calculate_metrics
      full_transcript = extract_full_transcript
      words = extract_words
      duration_ms = @transcript_data[:metadata][:duration] * 1000
      
      {
        word_count: words.length,
        duration_ms: duration_ms.to_i,
        speaking_rate_wpm: calculate_speaking_rate(words, duration_ms),
        filler_word_rate: calculate_filler_rate(full_transcript, words.length),
        average_pause_duration: calculate_average_pause_duration,
        longest_pause_duration: calculate_longest_pause_duration,
        clarity_score: calculate_clarity_score
      }
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
      metrics = calculate_metrics
      
      if metrics[:speaking_rate_wpm] < 120
        [{
          kind: 'pace_too_slow',
          start_ms: 0,
          end_ms: metrics[:duration_ms],
          text: extract_full_transcript[0..100] + '...',
          source: 'rule',
          rationale: rule[:description],
          tip: rule[:tip],
          severity: rule[:severity],
          speaking_rate: metrics[:speaking_rate_wpm]
        }]
      else
        []
      end
    end
    
    def detect_fast_speaking_rate(rule, category)
      metrics = calculate_metrics
      
      if metrics[:speaking_rate_wpm] > 180
        [{
          kind: 'pace_too_fast',
          start_ms: 0,
          end_ms: metrics[:duration_ms],
          text: extract_full_transcript[0..100] + '...',
          source: 'rule',
          rationale: rule[:description],
          tip: rule[:tip],
          severity: rule[:severity],
          speaking_rate: metrics[:speaking_rate_wpm]
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
      
      duration_minutes = duration_ms / 60_000.0
      words.length / duration_minutes
    end
    
    def calculate_filler_rate(transcript, word_count)
      return 0 if word_count == 0
      
      filler_patterns = @rules['filler_words'] || []
      total_fillers = 0
      
      filler_patterns.each do |rule|
        next unless rule[:regex].is_a?(Regexp)
        matches = transcript.scan(rule[:regex])
        total_fillers += matches.length
      end
      
      (total_fillers.to_f / word_count) * 100
    end
    
    def calculate_average_pause_duration
      words = extract_words
      return 0 if words.length < 2
      
      pauses = []
      words.each_cons(2) do |current, next_word|
        pause_ms = next_word[:start] - current[:end]
        pauses << pause_ms if pause_ms > 100 # Ignore very short gaps
      end
      
      pauses.empty? ? 0 : pauses.sum / pauses.length
    end
    
    def calculate_longest_pause_duration
      words = extract_words
      return 0 if words.length < 2
      
      longest_pause = 0
      words.each_cons(2) do |current, next_word|
        pause_ms = next_word[:start] - current[:end]
        longest_pause = [longest_pause, pause_ms].max
      end
      
      longest_pause
    end
    
    def calculate_clarity_score
      # Basic clarity score based on detected issues
      total_issues = @detected_issues.length
      issue_penalty = total_issues * 5
      
      base_score = 100
      clarity_score = [base_score - issue_penalty, 0].max
      
      clarity_score
    end
  end
end