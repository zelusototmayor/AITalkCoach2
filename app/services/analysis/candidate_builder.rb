module Analysis
  class CandidateBuilder
    class CandidateError < StandardError; end
    
    DEFAULT_MAX_CANDIDATES = 10
    DEFAULT_MIN_SEGMENT_DURATION = 2000 # 2 seconds
    DEFAULT_MAX_SEGMENT_DURATION = 15000 # 15 seconds
    DEFAULT_CONTEXT_BUFFER = 1000 # 1 second
    
    def initialize(transcript_data, detected_issues = [], options = {})
      @transcript_data = transcript_data
      @detected_issues = detected_issues
      @options = options
      @max_candidates = options[:max_candidates] || DEFAULT_MAX_CANDIDATES
      @min_duration = options[:min_segment_duration] || DEFAULT_MIN_SEGMENT_DURATION
      @max_duration = options[:max_segment_duration] || DEFAULT_MAX_SEGMENT_DURATION
      @context_buffer = options[:context_buffer] || DEFAULT_CONTEXT_BUFFER
    end
    
    def build_candidates
      candidates = []
      
      # Strategy 1: Issue-based candidates (highest priority)
      issue_candidates = build_issue_based_candidates
      candidates.concat(issue_candidates)
      
      # Strategy 2: Quality segments with diverse content
      if candidates.length < @max_candidates
        quality_candidates = build_quality_segment_candidates
        candidates.concat(quality_candidates)
      end
      
      # Strategy 3: Random sampling for coverage (if still under limit)
      if candidates.length < @max_candidates
        random_candidates = build_random_segment_candidates
        candidates.concat(random_candidates)
      end
      
      # Remove duplicates and sort by priority
      candidates = deduplicate_candidates(candidates)
      candidates = sort_candidates_by_priority(candidates)
      
      # Limit to max candidates
      candidates.first(@max_candidates)
    end
    
    private
    
    def build_issue_based_candidates
      candidates = []
      
      # Group issues by severity and type for intelligent sampling
      high_priority_issues = @detected_issues.select { |issue| issue[:severity] == 'high' }
      medium_priority_issues = @detected_issues.select { |issue| issue[:severity] == 'medium' }
      
      # Prioritize high severity issues first
      high_priority_issues.each do |issue|
        candidate = build_candidate_from_issue(issue, priority: 'high')
        candidates << candidate if candidate
        break if candidates.length >= (@max_candidates * 0.6).ceil # 60% for high priority
      end
      
      # Add medium priority issues if we have space
      medium_priority_issues.each do |issue|
        candidate = build_candidate_from_issue(issue, priority: 'medium')
        candidates << candidate if candidate
        break if candidates.length >= (@max_candidates * 0.8).ceil # 80% total for issues
      end
      
      candidates
    end
    
    def build_candidate_from_issue(issue, priority:)
      words = @transcript_data[:words] || []
      return nil if words.empty?
      
      # Find the segment around the issue with appropriate context
      start_ms = [issue[:start_ms] - @context_buffer, 0].max
      end_ms = issue[:end_ms] + @context_buffer
      
      # Ensure minimum duration
      if end_ms - start_ms < @min_duration
        duration_needed = @min_duration - (end_ms - start_ms)
        start_ms = [start_ms - duration_needed / 2, 0].max
        end_ms = end_ms + duration_needed / 2
      end
      
      # Ensure maximum duration
      if end_ms - start_ms > @max_duration
        duration_excess = (end_ms - start_ms) - @max_duration
        start_ms = start_ms + duration_excess / 2
        end_ms = end_ms - duration_excess / 2
      end
      
      # Extract segment text and metadata
      segment_words = words.select { |w| w[:start] >= start_ms && w[:end] <= end_ms }
      return nil if segment_words.empty?
      
      segment_text = segment_words.map { |w| w[:punctuated_word] || w[:word] }.join(' ')
      
      {
        start_ms: start_ms.to_i,
        end_ms: end_ms.to_i,
        text: segment_text,
        priority: priority,
        source: 'issue_based',
        related_issue: {
          kind: issue[:kind],
          pattern: issue[:pattern],
          severity: issue[:severity]
        },
        word_count: segment_words.length,
        duration_ms: end_ms - start_ms
      }
    end
    
    def build_quality_segment_candidates
      candidates = []
      words = @transcript_data[:words] || []
      return candidates if words.empty?
      
      # Look for segments with good speaking characteristics
      potential_segments = find_quality_segments(words)
      
      potential_segments.each do |segment|
        candidates << {
          start_ms: segment[:start_ms],
          end_ms: segment[:end_ms],
          text: segment[:text],
          priority: 'medium',
          source: 'quality_segment',
          word_count: segment[:word_count],
          duration_ms: segment[:duration_ms],
          quality_score: segment[:quality_score]
        }
        break if candidates.length >= (@max_candidates * 0.3).ceil
      end
      
      candidates
    end
    
    def find_quality_segments(words)
      segments = []
      segment_start = 0
      
      while segment_start < words.length
        segment_end = find_segment_end(words, segment_start)
        break if segment_end <= segment_start
        
        segment_words = words[segment_start..segment_end]
        segment = analyze_segment_quality(segment_words)
        
        if segment[:quality_score] > 0.6 # Only include quality segments
          segments << segment
        end
        
        segment_start = segment_end + 1
      end
      
      segments.sort_by { |s| -s[:quality_score] }
    end
    
    def find_segment_end(words, start_index)
      target_duration = (@min_duration + @max_duration) / 2 # Aim for middle duration
      current_duration = 0
      
      (start_index...words.length).each do |i|
        if i > start_index
          current_duration = words[i][:end] - words[start_index][:start]
          break if current_duration >= target_duration
        end
        
        # Check for natural break points (long pauses)
        if i < words.length - 1
          pause_duration = words[i + 1][:start] - words[i][:end]
          if pause_duration > 1500 && current_duration >= @min_duration # 1.5s pause
            return i
          end
        end
      end
      
      # Find the word that gets us closest to target duration
      (start_index...words.length).each do |i|
        duration = words[i][:end] - words[start_index][:start]
        return i if duration >= @min_duration
      end
      
      start_index
    end
    
    def analyze_segment_quality(segment_words)
      return { quality_score: 0 } if segment_words.empty?
      
      start_ms = segment_words.first[:start]
      end_ms = segment_words.last[:end]
      duration_ms = end_ms - start_ms
      text = segment_words.map { |w| w[:punctuated_word] || w[:word] }.join(' ')
      
      # Quality factors
      word_count = segment_words.length
      avg_word_length = segment_words.map { |w| (w[:word] || '').length }.sum.to_f / word_count
      
      # Calculate speaking rate for this segment
      speaking_rate = (word_count / (duration_ms / 60_000.0)).round(1)
      
      # Calculate pause distribution
      pause_variance = calculate_pause_variance(segment_words)
      
      # Quality scoring (0-1 scale)
      rate_score = speaking_rate_quality_score(speaking_rate)
      length_score = word_length_quality_score(avg_word_length)
      pause_score = pause_distribution_score(pause_variance)
      content_score = content_diversity_score(text)
      
      quality_score = (rate_score + length_score + pause_score + content_score) / 4.0
      
      {
        start_ms: start_ms,
        end_ms: end_ms,
        text: text,
        word_count: word_count,
        duration_ms: duration_ms,
        quality_score: quality_score,
        speaking_rate: speaking_rate,
        avg_word_length: avg_word_length
      }
    end
    
    def speaking_rate_quality_score(rate)
      # Optimal range is 140-160 WPM
      return 1.0 if rate.between?(140, 160)
      return 0.8 if rate.between?(120, 180)
      return 0.5 if rate.between?(100, 200)
      0.2
    end
    
    def word_length_quality_score(avg_length)
      # Prefer moderate word lengths (indicates varied vocabulary)
      return 1.0 if avg_length.between?(4.5, 6.5)
      return 0.7 if avg_length.between?(3.5, 7.5)
      0.4
    end
    
    def pause_distribution_score(variance)
      # Prefer moderate variance (not too choppy, not monotone)
      return 1.0 if variance.between?(200, 800)
      return 0.6 if variance.between?(100, 1200)
      0.3
    end
    
    def content_diversity_score(text)
      words = text.downcase.split
      unique_words = words.uniq.length
      diversity_ratio = unique_words.to_f / words.length
      
      # Higher diversity indicates more interesting content
      return 1.0 if diversity_ratio > 0.8
      return 0.7 if diversity_ratio > 0.6
      return 0.5 if diversity_ratio > 0.4
      0.3
    end
    
    def calculate_pause_variance(segment_words)
      return 0 if segment_words.length < 2
      
      pauses = []
      segment_words.each_cons(2) do |current, next_word|
        pause_ms = next_word[:start] - current[:end]
        pauses << pause_ms if pause_ms > 50 # Ignore very short gaps
      end
      
      return 0 if pauses.empty?
      
      mean = pauses.sum.to_f / pauses.length
      variance = pauses.map { |p| (p - mean) ** 2 }.sum / pauses.length
      Math.sqrt(variance)
    end
    
    def build_random_segment_candidates
      candidates = []
      words = @transcript_data[:words] || []
      return candidates if words.empty?
      
      # Generate random segments for coverage
      remaining_slots = @max_candidates - (build_issue_based_candidates.length + build_quality_segment_candidates.length)
      
      remaining_slots.times do
        start_index = rand(words.length - 10) # Ensure some words after start
        segment_end = find_segment_end(words, start_index)
        
        next if segment_end <= start_index
        
        segment_words = words[start_index..segment_end]
        text = segment_words.map { |w| w[:punctuated_word] || w[:word] }.join(' ')
        
        candidates << {
          start_ms: segment_words.first[:start],
          end_ms: segment_words.last[:end],
          text: text,
          priority: 'low',
          source: 'random_sampling',
          word_count: segment_words.length,
          duration_ms: segment_words.last[:end] - segment_words.first[:start]
        }
      end
      
      candidates
    end
    
    def deduplicate_candidates(candidates)
      # Remove overlapping candidates, keeping higher priority ones
      candidates.sort_by! { |c| priority_sort_value(c[:priority]) }
      
      unique_candidates = []
      candidates.each do |candidate|
        overlaps = unique_candidates.any? do |existing|
          segments_overlap?(candidate, existing)
        end
        
        unique_candidates << candidate unless overlaps
      end
      
      unique_candidates
    end
    
    def segments_overlap?(seg1, seg2)
      # Check if segments have significant overlap (>30%)
      overlap_start = [seg1[:start_ms], seg2[:start_ms]].max
      overlap_end = [seg1[:end_ms], seg2[:end_ms]].min
      
      return false if overlap_end <= overlap_start
      
      overlap_duration = overlap_end - overlap_start
      min_duration = [seg1[:duration_ms], seg2[:duration_ms]].min
      
      (overlap_duration.to_f / min_duration) > 0.3
    end
    
    def sort_candidates_by_priority(candidates)
      candidates.sort_by do |candidate|
        [
          priority_sort_value(candidate[:priority]),
          -(candidate[:quality_score] || 0.5),
          candidate[:start_ms]
        ]
      end
    end
    
    def priority_sort_value(priority)
      case priority
      when 'high' then 1
      when 'medium' then 2
      when 'low' then 3
      else 4
      end
    end
  end
end