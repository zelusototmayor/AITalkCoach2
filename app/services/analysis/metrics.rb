module Analysis
  class Metrics
    class MetricsError < StandardError; end
    
    # Standard speech rate ranges (words per minute)
    OPTIMAL_WPM_RANGE = (140..160).freeze
    ACCEPTABLE_WPM_RANGE = (120..180).freeze
    SLOW_WPM_THRESHOLD = 120
    FAST_WPM_THRESHOLD = 180
    
    # Clarity scoring weights
    CLARITY_WEIGHTS = {
      filler_rate: 0.3,
      pace_consistency: 0.25,
      pause_quality: 0.2,
      articulation: 0.15,
      fluency: 0.1
    }.freeze
    
    def initialize(transcript_data, issues = [], options = {})
      @transcript_data = transcript_data
      @issues = Array(issues)
      @options = options
      @language = options[:language] || 'en'
    end
    
    def calculate_all_metrics
      {
        basic_metrics: calculate_basic_metrics,
        speaking_metrics: calculate_speaking_metrics,
        clarity_metrics: calculate_clarity_metrics,
        fluency_metrics: calculate_fluency_metrics,
        engagement_metrics: calculate_engagement_metrics,
        overall_scores: calculate_overall_scores,
        metadata: {
          calculation_time: Time.current,
          transcript_quality: assess_transcript_quality,
          confidence_level: calculate_confidence_level
        }
      }
    rescue => e
      Rails.logger.error "Metrics calculation error: #{e.message}"
      raise MetricsError, "Failed to calculate metrics: #{e.message}"
    end

    def extract_coaching_insights
      words = extract_words
      basic = calculate_basic_metrics
      speaking = calculate_speaking_metrics
      clarity = calculate_clarity_metrics
      fluency = calculate_fluency_metrics
      engagement = calculate_engagement_metrics

      {
        pause_patterns: extract_pause_patterns(clarity[:pause_metrics]),
        pace_patterns: extract_pace_patterns(words, speaking),
        energy_patterns: extract_energy_patterns(engagement),
        smoothness_breakdown: extract_smoothness_breakdown(clarity, fluency),
        hesitation_analysis: extract_hesitation_analysis(words, clarity[:filler_metrics])
      }
    rescue => e
      Rails.logger.error "Coaching insights extraction error: #{e.message}"
      {}
    end
    
    def calculate_basic_metrics
      words = extract_words
      duration_ms = extract_duration_ms
      
      {
        word_count: words.length,
        unique_word_count: count_unique_words(words),
        duration_ms: duration_ms,
        duration_seconds: (duration_ms / 1000.0).round(2),
        speaking_time_ms: calculate_speaking_time(words),
        pause_time_ms: calculate_total_pause_time(words),
        average_word_length: calculate_average_word_length(words),
        syllable_count: estimate_syllable_count(words)
      }
    end
    
    def calculate_speaking_metrics
      words = extract_words
      duration_ms = extract_duration_ms
      speaking_time_ms = calculate_speaking_time(words)
      
      return default_speaking_metrics if words.empty? || duration_ms <= 0
      
      # Core speaking rate calculations
      wpm = calculate_words_per_minute(words, duration_ms)
      effective_wpm = calculate_effective_wpm(words, speaking_time_ms)

      {
        words_per_minute: wpm.round(1),
        effective_words_per_minute: effective_wpm.round(1),
        speaking_rate_assessment: assess_speaking_rate(wpm),
        pace_consistency: (calculate_pace_consistency(words) / 100.0).round(4),
        pace_variation_coefficient: calculate_pace_variation_coefficient(words),
        speech_to_silence_ratio: calculate_speech_to_silence_ratio(speaking_time_ms, duration_ms)
      }
    end
    
    def calculate_clarity_metrics
      words = extract_words
      
      filler_metrics = calculate_filler_metrics(words)
      pause_metrics = calculate_pause_metrics(words)
      articulation_score = calculate_articulation_score
      
      # Weighted clarity score (ensure all components are 0-100)
      clarity_components = {
        filler_rate: (100 - filler_metrics[:filler_rate_percentage]).clamp(0, 100),
        pace_consistency: calculate_pace_clarity_score.clamp(0, 100),
        pause_quality: (pause_metrics[:pause_quality_score] || 50).clamp(0, 100),
        articulation: articulation_score.clamp(0, 100),
        fluency: calculate_fluency_score(words).clamp(0, 100)
      }

      weighted_clarity = calculate_weighted_score(clarity_components, CLARITY_WEIGHTS).clamp(0, 100)
      
      {
        clarity_score: (weighted_clarity / 100.0).round(4),
        clarity_components: clarity_components,
        filler_metrics: filler_metrics,
        pause_metrics: pause_metrics,
        articulation_score: articulation_score
      }
    end
    
    def calculate_fluency_metrics
      words = extract_words
      
      {
        fluency_score: (calculate_fluency_score(words) / 100.0).round(4),
        hesitation_count: count_hesitations,
        restart_count: count_restarts,
        incomplete_thoughts: count_incomplete_thoughts,
        flow_interruptions: count_flow_interruptions,
        speech_smoothness: calculate_speech_smoothness(words)
      }
    end
    
    def calculate_engagement_metrics
      words = extract_words
      
      {
        energy_level: calculate_energy_level,
        pace_variation: calculate_pace_variation_score,
        emphasis_patterns: detect_emphasis_patterns,
        question_usage: count_questions,
        exclamation_usage: count_exclamations,
        engagement_score: (calculate_overall_engagement_score / 100.0).round(4)
      }
    end
    
    def calculate_overall_scores
      basic = calculate_basic_metrics
      speaking = calculate_speaking_metrics
      clarity = calculate_clarity_metrics
      fluency = calculate_fluency_metrics
      engagement = calculate_engagement_metrics
      
      # Get component scores and normalize to 0-1 range
      pace_score = score_speaking_pace(speaking[:words_per_minute]) / 100.0  # Convert from 0-100 to 0-1
      clarity_score = clarity[:clarity_score]  # Already 0-1
      fluency_score = fluency[:fluency_score]  # Already 0-1
      engagement_score = engagement[:engagement_score]  # Already 0-1

      # Overall weighted score
      component_weights = {
        pace: 0.25,
        clarity: 0.35,
        fluency: 0.25,
        engagement: 0.15
      }

      # All component scores are now decimals (0-1), multiply by 100 for calculation
      overall_score = (
        (pace_score * 100) * component_weights[:pace] +
        (clarity_score * 100) * component_weights[:clarity] +
        (fluency_score * 100) * component_weights[:fluency] +
        (engagement_score * 100) * component_weights[:engagement]
      ).round(1)

      {
        overall_score: (overall_score / 100.0).round(4),  # Convert back to decimal for storage
        component_scores: {
          pace_score: pace_score.round(4),  # Already decimal
          clarity_score: clarity_score.round(4),  # Already decimal
          fluency_score: fluency_score.round(4),  # Already decimal
          engagement_score: engagement_score.round(4)  # Already decimal
        },
        grade: score_to_grade(overall_score),
        improvement_potential: calculate_improvement_potential(overall_score),
        strengths: identify_strengths(component_weights.keys.zip([(pace_score * 100), (clarity_score * 100), (fluency_score * 100), (engagement_score * 100)])),
        areas_for_improvement: identify_improvement_areas(component_weights.keys.zip([(pace_score * 100), (clarity_score * 100), (fluency_score * 100), (engagement_score * 100)]))
      }
    end
    
    private

    # Coaching insights extraction methods

    def extract_pause_patterns(pause_metrics)
      distribution = pause_metrics[:pause_distribution] || {}
      optimal_pct = distribution.dig('optimal', :percentage) || 0
      long_pct = distribution.dig('long', :percentage) || 0
      very_long_pct = distribution.dig('very_long', :percentage) || 0

      quality_breakdown = if pause_metrics[:pause_quality_score] >= 80
        'mostly_optimal'
      elsif long_pct > 20 || very_long_pct > 10
        'mostly_good_with_awkward_long_pauses'
      elsif optimal_pct < 40
        'inconsistent_timing'
      else
        'generally_acceptable'
      end

      specific_issue = nil
      if pause_metrics[:long_pause_count] > 0
        specific_issue = "#{pause_metrics[:long_pause_count]} pauses over 3 seconds"
      end

      {
        distribution: {
          optimal: optimal_pct,
          acceptable: distribution.dig('acceptable', :percentage) || 0,
          long: long_pct,
          very_long: very_long_pct
        },
        quality_breakdown: quality_breakdown,
        specific_issue: specific_issue,
        average_pause_ms: pause_metrics[:average_pause_ms],
        longest_pause_ms: pause_metrics[:longest_pause_ms]
      }
    end

    def extract_pace_patterns(words, speaking_metrics)
      return default_pace_patterns if words.length < 10

      # Analyze pace trajectory throughout session
      segment_size = [words.length / 5, 10].max.to_i
      segment_wpms = []

      (0...words.length).step(segment_size) do |i|
        segment = words[i, segment_size]
        next if segment.length < 3

        duration = segment.last[:end] - segment.first[:start]
        next if duration <= 0

        wpm = (segment.length / (duration / 60_000.0))
        segment_wpms << wpm
      end

      trajectory = analyze_pace_trajectory(segment_wpms)
      consistency = speaking_metrics[:pace_consistency] || 0
      variation_type = categorize_pace_variation(segment_wpms, consistency)

      {
        trajectory: trajectory,
        consistency: consistency,
        variation_type: variation_type,
        wpm_range: segment_wpms.empty? ? [0, 0] : [segment_wpms.min.round, segment_wpms.max.round],
        average_wpm: speaking_metrics[:words_per_minute]
      }
    end

    def analyze_pace_trajectory(segment_wpms)
      return 'insufficient_data' if segment_wpms.length < 3

      first_third = segment_wpms[0...(segment_wpms.length / 3)]
      middle_third = segment_wpms[(segment_wpms.length / 3)...(2 * segment_wpms.length / 3)]
      last_third = segment_wpms[(2 * segment_wpms.length / 3)..-1]

      avg_first = first_third.sum / first_third.length.to_f
      avg_middle = middle_third.sum / middle_third.length.to_f
      avg_last = last_third.sum / last_third.length.to_f

      if avg_middle > avg_first * 1.2 && avg_last < avg_middle * 0.9
        'starts_slow_rushes_middle_settles'
      elsif avg_middle > avg_first * 1.15
        'starts_slow_accelerates'
      elsif avg_first > avg_last * 1.15
        'starts_fast_decelerates'
      elsif (avg_first - avg_last).abs < avg_first * 0.1
        'consistent_throughout'
      else
        'variable'
      end
    end

    def categorize_pace_variation(segment_wpms, consistency)
      return 'unknown' if segment_wpms.empty?

      cv = coefficient_of_variation(segment_wpms)

      if cv > 0.3
        'high_variance'
      elsif cv > 0.2
        'moderate_variance'
      elsif cv < 0.1
        'very_consistent'
      else
        'low_variance'
      end
    end

    def extract_energy_patterns(engagement_metrics)
      energy_level = engagement_metrics[:energy_level] || 50
      exclamations = engagement_metrics[:exclamation_usage] || 0
      questions = engagement_metrics[:question_usage] || 0

      pattern = if energy_level < 40
        'low_energy_throughout'
      elsif energy_level > 75
        'high_energy_throughout'
      else
        'moderate_energy'
      end

      engagement_elements = []
      engagement_elements << "#{exclamations} exclamations" if exclamations > 0
      engagement_elements << "#{questions} questions" if questions > 0

      {
        overall_level: energy_level,
        pattern: pattern,
        engagement_elements: engagement_elements,
        needs_boost: energy_level < 50
      }
    end

    def extract_smoothness_breakdown(clarity_metrics, fluency_metrics)
      smoothness = fluency_metrics[:speech_smoothness] || 70
      pause_quality = clarity_metrics[:pause_metrics][:pause_quality_score] || 50

      word_flow_score = (smoothness * 0.6 + pause_quality * 0.4).round(1)

      primary_issue = if fluency_metrics[:hesitation_count] > 5
        'frequent_hesitations'
      elsif fluency_metrics[:restart_count] > 3
        'frequent_restarts'
      elsif pause_quality < 50
        'irregular_pauses'
      elsif smoothness < 60
        'choppy_word_delivery'
      else
        nil
      end

      {
        word_flow_score: word_flow_score,
        pause_consistency_score: pause_quality,
        primary_issue: primary_issue,
        hesitation_count: fluency_metrics[:hesitation_count],
        restart_count: fluency_metrics[:restart_count]
      }
    end

    def extract_hesitation_analysis(words, filler_metrics)
      transcript = extract_transcript_text.downcase
      filler_breakdown = filler_metrics[:filler_breakdown] || {}

      # Analyze where hesitations occur
      hesitation_locations = analyze_hesitation_locations(words)

      most_common_filler = filler_breakdown.max_by { |_, count| count }&.first
      total_fillers = filler_metrics[:total_filler_count] || 0

      {
        total_count: total_fillers,
        rate_percentage: filler_metrics[:filler_rate_percentage] || 0,
        most_common: most_common_filler,
        breakdown: filler_breakdown,
        typical_locations: hesitation_locations,
        density: filler_metrics[:filler_density]
      }
    end

    def analyze_hesitation_locations(words)
      # Simple heuristic: check if hesitations are at start, middle, or end
      # This is a placeholder for more sophisticated analysis
      transcript = extract_transcript_text.downcase
      sentences = transcript.split(/[.!?]+/)

      start_hesitations = 0
      sentences.each do |sentence|
        words = sentence.strip.split
        start_hesitations += 1 if words.first&.match?(/^(um|uh|er|ah|like)$/)
      end

      if start_hesitations > sentences.length * 0.5
        'mostly_at_sentence_starts'
      else
        'distributed_throughout'
      end
    end

    def default_pace_patterns
      {
        trajectory: 'insufficient_data',
        consistency: 0,
        variation_type: 'unknown',
        wpm_range: [0, 0],
        average_wpm: 0
      }
    end

    def extract_words
      @transcript_data[:words] || []
    end
    
    def extract_duration_ms
      (@transcript_data.dig(:metadata, :duration) || 0) * 1000
    end
    
    def extract_transcript_text
      @transcript_data[:transcript] || ''
    end
    
    def count_unique_words(words)
      words.map { |w| (w[:word] || '').downcase }.uniq.length
    end
    
    def calculate_speaking_time(words)
      return 0 if words.empty?
      
      total_word_duration = 0
      words.each do |word|
        total_word_duration += (word[:end] - word[:start])
      end
      total_word_duration
    end
    
    def calculate_total_pause_time(words)
      total_duration = extract_duration_ms
      speaking_time = calculate_speaking_time(words)
      [total_duration - speaking_time, 0].max
    end
    
    def calculate_average_word_length(words)
      return 0 if words.empty?
      
      total_length = words.sum { |w| (w[:word] || '').length }
      (total_length.to_f / words.length).round(2)
    end
    
    def estimate_syllable_count(words)
      # Simple syllable estimation based on vowel patterns
      total_syllables = 0
      
      words.each do |word|
        word_text = (word[:word] || '').downcase
        # Count vowel groups (rough syllable estimation)
        syllable_count = word_text.scan(/[aeiouy]+/).length
        syllable_count = 1 if syllable_count == 0 && !word_text.empty?
        total_syllables += syllable_count
      end
      
      total_syllables
    end
    
    def calculate_words_per_minute(words, duration_ms)
      return 0 if words.empty? || duration_ms <= 0

      duration_minutes = duration_ms / 60_000.0
      words.length / duration_minutes
    end
    
    def calculate_effective_wpm(words, speaking_time_ms)
      return 0 if words.empty? || speaking_time_ms <= 0
      
      speaking_minutes = speaking_time_ms / 60_000.0
      words.length / speaking_minutes
    end
    
    def assess_speaking_rate(wpm)
      case wpm
      when 0..SLOW_WPM_THRESHOLD
        'too_slow'
      when SLOW_WPM_THRESHOLD..OPTIMAL_WPM_RANGE.min
        'slow'
      when OPTIMAL_WPM_RANGE
        'optimal'
      when OPTIMAL_WPM_RANGE.max..FAST_WPM_THRESHOLD
        'fast'
      else
        'too_fast'
      end
    end
    
    def calculate_pace_consistency(words)
      return 100 if words.length < 10
      
      # Calculate WPM for sliding windows
      window_size = [words.length / 5, 10].max.to_i
      window_wpms = []
      
      (0..words.length - window_size).step(window_size / 2) do |i|
        window_words = words[i, window_size]
        next if window_words.empty?
        
        window_duration = window_words.last[:end] - window_words.first[:start]
        next if window_duration <= 0
        
        window_wpm = (window_words.length / (window_duration / 60_000.0))
        window_wpms << window_wpm
      end
      
      return 100 if window_wpms.length < 2
      
      # Calculate coefficient of variation (lower is more consistent)
      mean = window_wpms.sum / window_wpms.length
      variance = window_wpms.sum { |wpm| (wpm - mean) ** 2 } / window_wpms.length
      cv = Math.sqrt(variance) / mean
      
      # Convert to 0-100 score (lower variation = higher score)
      consistency_score = [100 - (cv * 100), 0].max
      consistency_score.round(1)
    end
    
    def calculate_pace_variation_coefficient(words)
      return 0 if words.length < 2
      
      pause_durations = []
      words.each_cons(2) do |current, next_word|
        pause = next_word[:start] - current[:end]
        pause_durations << pause if pause > 50 # Ignore very short gaps
      end
      
      return 0 if pause_durations.empty?
      
      mean = pause_durations.sum.to_f / pause_durations.length
      return 0 if mean == 0
      
      variance = pause_durations.sum { |p| (p - mean) ** 2 } / pause_durations.length
      (Math.sqrt(variance) / mean).round(3)
    end
    
    def calculate_speech_to_silence_ratio(speaking_time_ms, total_duration_ms)
      return 0 if total_duration_ms <= 0
      
      silence_time_ms = total_duration_ms - speaking_time_ms
      return Float::INFINITY if silence_time_ms <= 0
      
      (speaking_time_ms.to_f / silence_time_ms).round(2)
    end
    
    def calculate_filler_metrics(words)
      transcript = extract_transcript_text.downcase
      total_words = words.length

      # Get language-specific filler patterns
      filler_patterns = filler_patterns_for_language(@language)

      filler_counts = {}
      total_fillers = 0

      filler_patterns.each do |type, pattern|
        matches = transcript.scan(pattern).length
        filler_counts[type] = matches
        total_fillers += matches
      end

      # Calculate filler rate as a decimal (0.01 = 1%)
      filler_rate_decimal = total_words > 0 ? (total_fillers.to_f / total_words) : 0
      filler_rate_percentage = filler_rate_decimal * 100

      {
        total_filler_count: total_fillers,
        filler_rate_percentage: filler_rate_percentage.round(2),
        filler_rate_decimal: filler_rate_decimal.round(4), # For storage as decimal
        filler_rate_per_minute: calculate_fillers_per_minute(total_fillers),
        filler_breakdown: filler_counts,
        filler_density: assess_filler_density(filler_rate_percentage)
      }
    end

    def filler_patterns_for_language(language)
      case language
      when 'pt'
        # Portuguese (Portugal) filler words and patterns
        {
          'eh' => /\b(eh|é)\b/i,
          'ah' => /\b(ah|hm|ahn)\b/i,
          'tipo' => /\btipo\b/i,
          'ne' => /\bné\b/i,
          'entao' => /\bentão\b/i,
          'assim' => /\bassim\b/i,
          'sei_la' => /\bsei lá\b/i,
          'meio_que' => /\bmeio que\b/i,
          'tipo_assim' => /\btipo assim\b/i,
          'mais_ou_menos' => /\bmais ou menos\b/i
        }
      when 'es'
        # Spanish filler words and patterns
        {
          'eh' => /\b(eh|este|esto)\b/i,
          'pues' => /\bpues\b/i,
          'bueno' => /\bbueno\b/i,
          'o_sea' => /\bo sea\b/i,
          'como' => /\bcomo\b(?!\s+(que|si|cuando))/i
        }
      else
        # English (default) filler words and patterns
        {
          'um' => /\b(um|uhm)\b/i,
          'uh' => /\b(uh|er|ah)\b/i,
          'like' => /\blike\b/i,
          'you_know' => /\byou know\b/i,
          'basically' => /\bbasically\b/i,
          'actually' => /\bactually\b/i,
          'so' => /\bso\b(?!\s+(that|what|how|when|where|why))/i
        }
      end
    end
    
    def calculate_fillers_per_minute(total_fillers)
      duration_minutes = extract_duration_ms / 60_000.0
      return 0 if duration_minutes <= 0
      
      (total_fillers / duration_minutes).round(1)
    end
    
    def assess_filler_density(filler_rate)
      case filler_rate
      when 0..2 then 'excellent'
      when 2..5 then 'good'
      when 5..10 then 'moderate'
      when 10..15 then 'high'
      else 'very_high'
      end
    end
    
    def calculate_pause_metrics(words)
      return default_pause_metrics if words.length < 2
      
      pauses = []
      words.each_cons(2) do |current, next_word|
        pause_duration = next_word[:start] - current[:end]
        pauses << pause_duration if pause_duration > 100 # Ignore very short gaps
      end
      
      return default_pause_metrics if pauses.empty?
      
      avg_pause = pauses.sum / pauses.length
      longest_pause = pauses.max
      shortest_pause = pauses.min
      
      # Count problematic pauses
      long_pauses = pauses.count { |p| p > 3000 } # > 3 seconds
      very_short_pauses = pauses.count { |p| p < 200 } # < 0.2 seconds
      
      # Quality assessment
      pause_quality = assess_pause_quality(avg_pause, longest_pause, long_pauses, pauses.length)
      
      {
        total_pause_count: pauses.length,
        average_pause_ms: avg_pause.round,
        longest_pause_ms: longest_pause,
        shortest_pause_ms: shortest_pause,
        long_pause_count: long_pauses,
        very_short_pause_count: very_short_pauses,
        pause_quality_score: pause_quality,
        pause_distribution: calculate_pause_distribution(pauses)
      }
    end
    
    def assess_pause_quality(avg_pause, longest_pause, long_pause_count, total_pauses)
      base_score = 100
      
      # Penalize very long average pauses
      if avg_pause > 1500 # 1.5 seconds
        base_score -= 20
      elsif avg_pause > 1000 # 1 second
        base_score -= 10
      end
      
      # Penalize extremely long individual pauses
      if longest_pause > 5000 # 5 seconds
        base_score -= 30
      elsif longest_pause > 3000 # 3 seconds
        base_score -= 15
      end
      
      # Penalize too many long pauses
      if total_pauses > 0
        long_pause_ratio = long_pause_count.to_f / total_pauses
        if long_pause_ratio > 0.2 # More than 20% are long pauses
          base_score -= 25
        elsif long_pause_ratio > 0.1 # More than 10% are long pauses
          base_score -= 10
        end
      end
      
      [base_score, 0].max
    end
    
    def calculate_pause_distribution(pauses)
      ranges = {
        'optimal' => (200..800),      # 0.2-0.8 seconds
        'acceptable' => (800..1500),  # 0.8-1.5 seconds
        'long' => (1500..3000),       # 1.5-3 seconds
        'very_long' => (3000..Float::INFINITY) # > 3 seconds
      }
      
      distribution = {}
      ranges.each do |category, range|
        count = pauses.count { |p| range.include?(p) }
        percentage = pauses.empty? ? 0 : (count.to_f / pauses.length * 100).round(1)
        distribution[category] = { count: count, percentage: percentage }
      end
      
      distribution
    end
    
    def calculate_articulation_score
      # This is a placeholder for articulation analysis
      # In a real implementation, this would analyze phonetic patterns,
      # word clarity, and pronunciation issues
      
      issue_penalty = @issues.select { |i| i[:kind] == 'articulation' }.length * 10
      base_score = 90 - issue_penalty
      
      [base_score, 0].max
    end
    
    def calculate_fluency_score(words)
      base_score = 100

      # Factor in hesitations and restarts
      base_score -= count_hesitations * 5
      base_score -= count_restarts * 8
      base_score -= count_incomplete_thoughts * 10

      # Factor in speech smoothness (using weighted contribution, not multiplication)
      smoothness = calculate_speech_smoothness(words)
      smoothness_adjustment = (smoothness - 70) * 0.2 # Only adjust if above/below average
      base_score += smoothness_adjustment

      # Ensure score stays within valid range
      [[base_score, 0].max, 100].min.round(1)
    end
    
    def count_hesitations
      transcript = extract_transcript_text.downcase
      hesitation_patterns = [
        /\b(um|uh|er|ah|hmm)\b/i,
        /\.\.\./,  # ellipses indicating hesitation
        /--/       # dashes indicating hesitation
      ]
      
      hesitation_patterns.sum { |pattern| transcript.scan(pattern).length }
    end
    
    def count_restarts
      transcript = extract_transcript_text
      # Look for patterns like "I was-- I mean"
      restart_pattern = /\b\w+--?\s+\w+/
      transcript.scan(restart_pattern).length
    end
    
    def count_incomplete_thoughts
      transcript = extract_transcript_text
      # Look for trailing off patterns
      incomplete_patterns = [
        /\b(and|but|so|then)\s*\.\.\./i,
        /\b(i|we|they|it)\s+(was|were|will|would|should)\s*\.\.\./i
      ]
      
      incomplete_patterns.sum { |pattern| transcript.scan(pattern).length }
    end
    
    def count_flow_interruptions
      # Count only unique flow interruptions, avoid double counting with fluency deductions
      long_pause_issues = @issues.count { |i| i[:kind] == 'long_pause' }
      unusual_patterns = count_restarts + count_incomplete_thoughts

      long_pause_issues + unusual_patterns
    end
    
    def calculate_speech_smoothness(words)
      return 100 if words.length < 5
      
      # Measure variation in word timing
      word_durations = words.map { |w| w[:end] - w[:start] }
      pause_durations = []
      
      words.each_cons(2) do |current, next_word|
        pause_durations << next_word[:start] - current[:end]
      end
      
      # Calculate coefficients of variation
      word_cv = coefficient_of_variation(word_durations)
      pause_cv = coefficient_of_variation(pause_durations)
      
      # Lower variation = higher smoothness
      word_smoothness = [100 - (word_cv * 50), 0].max
      pause_smoothness = [100 - (pause_cv * 30), 0].max
      
      ((word_smoothness + pause_smoothness) / 2).round(1)
    end
    
    def coefficient_of_variation(values)
      return 0 if values.empty? || values.length < 2
      
      mean = values.sum.to_f / values.length
      return 0 if mean == 0
      
      variance = values.sum { |v| (v - mean) ** 2 } / values.length
      Math.sqrt(variance) / mean
    end
    
    def calculate_energy_level
      # Analyze patterns that indicate energy/enthusiasm
      transcript = extract_transcript_text
      
      energy_indicators = {
        exclamations: transcript.scan(/!/).length,
        all_caps: transcript.scan(/\b[A-Z]{2,}\b/).length,
        emphasis_words: transcript.downcase.scan(/\b(amazing|fantastic|incredible|wow|great|excellent)\b/).length,
        question_engagement: transcript.scan(/\?/).length
      }
      
      # Simple energy calculation (could be more sophisticated)
      total_words = extract_words.length
      return 50 if total_words == 0
      
      energy_ratio = energy_indicators.values.sum.to_f / total_words
      energy_score = [50 + (energy_ratio * 500), 100].min
      
      energy_score.round(1)
    end
    
    def calculate_pace_variation_score
      words = extract_words
      return 50 if words.length < 10
      
      # Calculate WPM for segments
      segment_size = [words.length / 5, 5].max
      segment_wpms = []
      
      (0...words.length).step(segment_size) do |i|
        segment = words[i, segment_size]
        next if segment.length < 3
        
        duration = segment.last[:end] - segment.first[:start]
        next if duration <= 0
        
        wpm = (segment.length / (duration / 60_000.0))
        segment_wpms << wpm
      end
      
      return 50 if segment_wpms.length < 2
      
      # Good variation is moderate (not too monotone, not too erratic)
      cv = coefficient_of_variation(segment_wpms)
      
      # Optimal CV is around 0.2-0.4
      if cv.between?(0.2, 0.4)
        100
      elsif cv.between?(0.1, 0.6)
        80
      elsif cv.between?(0.05, 0.8)
        60
      else
        40
      end
    end
    
    def detect_emphasis_patterns
      transcript = extract_transcript_text
      
      {
        repetition_emphasis: transcript.scan(/\b(\w+)\s+\1\b/i).length,
        exclamation_emphasis: transcript.scan(/!/).length,
        caps_emphasis: transcript.scan(/\b[A-Z]{2,}\b/).length,
        question_engagement: transcript.scan(/\?/).length
      }
    end
    
    def count_questions
      extract_transcript_text.scan(/\?/).length
    end
    
    def count_exclamations
      extract_transcript_text.scan(/!/).length
    end
    
    def calculate_overall_engagement_score
      energy = calculate_energy_level
      variation = calculate_pace_variation_score
      emphasis = detect_emphasis_patterns.values.sum
      
      base_score = (energy + variation) / 2
      emphasis_bonus = [emphasis * 2, 20].min # Cap emphasis bonus at 20 points
      
      [base_score + emphasis_bonus, 100].min.round(1)
    end
    
    def calculate_pace_clarity_score
      wpm = calculate_words_per_minute(extract_words, extract_duration_ms)
      score_speaking_pace(wpm)
    end
    
    def score_speaking_pace(wpm)
      case wpm
      when OPTIMAL_WPM_RANGE then 100
      when ACCEPTABLE_WPM_RANGE then 85
      when 100..SLOW_WPM_THRESHOLD then 70
      when FAST_WPM_THRESHOLD..200 then 70
      when 80..100 then 50
      when 200..250 then 50
      else 30
      end
    end
    
    def calculate_weighted_score(components, weights)
      total_weighted = 0
      total_weight = 0
      
      components.each do |component, score|
        weight = weights[component] || 0
        total_weighted += score * weight
        total_weight += weight
      end
      
      return 0 if total_weight == 0
      total_weighted / total_weight
    end
    
    def score_to_grade(score)
      if score >= 90
        'A'
      elsif score >= 80
        'B'
      elsif score >= 70
        'C'
      elsif score >= 60
        'D'
      else
        'F'
      end
    end
    
    def calculate_improvement_potential(current_score)
      potential = 100 - current_score
      case potential
      when 0..10 then 'minimal'
      when 10..25 then 'moderate'
      when 25..40 then 'significant'
      else 'high'
      end
    end
    
    def identify_strengths(component_scores)
      component_scores
        .select { |_, score| score >= 80 }
        .sort_by { |_, score| -score }
        .first(3)
        .map { |component, _| component.to_s.humanize }
    end
    
    def identify_improvement_areas(component_scores)
      component_scores
        .select { |_, score| score < 75 }
        .sort_by { |_, score| score }
        .first(3)
        .map { |component, _| component.to_s.humanize }
    end
    
    def assess_transcript_quality
      words = extract_words
      transcript = extract_transcript_text
      
      quality_indicators = {
        has_timing: words.any? { |w| w[:start] && w[:end] },
        has_punctuation: transcript.match?(/[.!?]/),
        reasonable_length: transcript.length > 50,
        word_confidence: words.any? { |w| w[:confidence] }
      }
      
      quality_score = quality_indicators.values.count(true).to_f / quality_indicators.length
      
      case quality_score
      when 0.8..1.0 then 'high'
      when 0.6..0.8 then 'medium'
      when 0.4..0.6 then 'low'
      else 'very_low'
      end
    end
    
    def calculate_confidence_level
      words = extract_words
      transcript = extract_transcript_text
      
      # Base confidence on data completeness
      base_confidence = 0.7
      
      # Boost for complete timing data
      base_confidence += 0.1 if words.all? { |w| w[:start] && w[:end] }
      
      # Boost for reasonable transcript length
      base_confidence += 0.1 if transcript.length > 100
      
      # Reduce for very short recordings
      base_confidence -= 0.2 if extract_duration_ms < 5000 # Less than 5 seconds
      
      # Reduce for very few words
      base_confidence -= 0.2 if words.length < 10
      
      [base_confidence, 1.0].min.round(2)
    end
    
    # Default values for error conditions
    
    def default_speaking_metrics
      {
        words_per_minute: 0,
        effective_words_per_minute: 0,
        speaking_rate_assessment: 'unknown',
        pace_consistency: 0,
        pace_variation_coefficient: 0,
        speech_to_silence_ratio: 0
      }
    end
    
    def default_pause_metrics
      {
        total_pause_count: 0,
        average_pause_ms: 0,
        longest_pause_ms: 0,
        shortest_pause_ms: 0,
        long_pause_count: 0,
        very_short_pause_count: 0,
        pause_quality_score: 50,
        pause_distribution: {}
      }
    end
  end
end