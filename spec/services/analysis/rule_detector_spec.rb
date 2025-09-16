require 'rails_helper'

RSpec.describe Analysis::RuleDetector do
  let(:sample_transcript_data) do
    {
      transcript: "Um, hello everyone. This is, uh, a test recording with some filler words.",
      words: [
        { word: "Um", punctuated_word: "Um,", start: 0, end: 500, confidence: 0.9 },
        { word: "hello", punctuated_word: "hello", start: 700, end: 1200, confidence: 0.95 },
        { word: "everyone", punctuated_word: "everyone.", start: 1300, end: 2000, confidence: 0.92 },
        { word: "This", punctuated_word: "This", start: 2500, end: 2800, confidence: 0.88 },
        { word: "is", punctuated_word: "is,", start: 2900, end: 3100, confidence: 0.91 },
        { word: "uh", punctuated_word: "uh,", start: 3200, end: 3400, confidence: 0.85 },
        { word: "a", punctuated_word: "a", start: 3500, end: 3600, confidence: 0.98 },
        { word: "test", punctuated_word: "test", start: 3700, end: 4000, confidence: 0.96 },
        { word: "recording", punctuated_word: "recording", start: 4100, end: 4800, confidence: 0.93 },
        { word: "with", punctuated_word: "with", start: 4900, end: 5200, confidence: 0.89 },
        { word: "some", punctuated_word: "some", start: 5300, end: 5600, confidence: 0.94 },
        { word: "filler", punctuated_word: "filler", start: 5700, end: 6100, confidence: 0.87 },
        { word: "words", punctuated_word: "words.", start: 6200, end: 6800, confidence: 0.92 }
      ],
      metadata: {
        duration: 7.0, # 7 seconds
        confidence: 0.91,
        language: "en"
      }
    }
  end
  
  let(:test_rules) do
    {
      'filler_words' => [
        {
          pattern: '\\b(um|uh|er|ah)\\b',
          regex: /\b(um|uh|er|ah)\b/i,
          description: 'Common filler words detected',
          tip: 'Try to pause instead of using filler words',
          severity: 'medium',
          category: 'filler_words',
          min_matches: 1,
          context_window: 3
        }
      ],
      'pace_issues' => [
        {
          pattern: 'speaking_rate_below_120',
          regex: :special_pattern,
          description: 'Speaking rate is too slow',
          tip: 'Try to speak at a more natural pace',
          severity: 'low',
          category: 'pace_issues'
        }
      ]
    }
  end
  
  let(:detector) { described_class.new(sample_transcript_data, language: 'en') }
  
  before do
    allow(Analysis::Rulepacks).to receive(:load_rules).with('en').and_return(test_rules)
  end
  
  describe '#initialize' do
    it 'sets up detector with transcript data and language' do
      expect(detector.instance_variable_get(:@transcript_data)).to eq(sample_transcript_data)
      expect(detector.instance_variable_get(:@language)).to eq('en')
      expect(detector.instance_variable_get(:@rules)).to eq(test_rules)
    end
    
    it 'defaults to English language' do
      detector = described_class.new(sample_transcript_data)
      expect(detector.instance_variable_get(:@language)).to eq('en')
    end
  end
  
  describe '#detect_all_issues' do
    it 'detects filler words in transcript' do
      issues = detector.detect_all_issues
      
      filler_issues = issues.select { |issue| issue[:kind] == 'filler_word' }
      expect(filler_issues.length).to be >= 2 # "um" and "uh"
      
      um_issue = filler_issues.find { |issue| issue[:text].include?('Um') }
      expect(um_issue).to be_present
      expect(um_issue[:start_ms]).to eq(0)
      expect(um_issue[:end_ms]).to eq(500)
      expect(um_issue[:source]).to eq('rule')
      expect(um_issue[:rationale]).to eq('Common filler words detected')
    end
    
    it 'sorts issues by start time' do
      issues = detector.detect_all_issues
      
      start_times = issues.map { |issue| issue[:start_ms] }
      expect(start_times).to eq(start_times.sort)
    end
    
    it 'includes context around detected issues' do
      issues = detector.detect_all_issues
      
      filler_issue = issues.first
      expect(filler_issue[:text]).to be_present
      expect(filler_issue[:text].length).to be > filler_issue[:matched_words]&.first&.length || 0
    end
  end
  
  describe '#detect_category_issues' do
    it 'detects issues only for specified category' do
      filler_issues = detector.detect_category_issues('filler_words')
      
      expect(filler_issues).to all(have_key(:kind))
      expect(filler_issues).to all(satisfy { |issue| issue[:category] == 'filler_words' })
    end
    
    it 'returns empty array for non-existent category' do
      issues = detector.detect_category_issues('non_existent')
      expect(issues).to eq([])
    end
    
    it 'handles symbol category names' do
      issues = detector.detect_category_issues(:filler_words)
      expect(issues).not_to be_empty
    end
  end
  
  describe '#calculate_metrics' do
    it 'calculates speech metrics correctly' do
      metrics = detector.calculate_metrics
      
      expect(metrics).to have_key(:word_count)
      expect(metrics).to have_key(:duration_ms)
      expect(metrics).to have_key(:speaking_rate_wpm)
      expect(metrics).to have_key(:filler_word_rate)
      expect(metrics).to have_key(:clarity_score)
      
      expect(metrics[:word_count]).to eq(13)
      expect(metrics[:duration_ms]).to eq(7000)
      expect(metrics[:speaking_rate_wpm]).to be > 0
    end
    
    it 'calculates speaking rate in words per minute' do
      metrics = detector.calculate_metrics
      
      # 13 words in 7 seconds = ~111 WPM
      expected_wpm = (13.0 / (7.0 / 60.0)).round
      expect(metrics[:speaking_rate_wpm]).to be_within(5).of(expected_wpm)
    end
    
    it 'calculates filler word rate as percentage' do
      metrics = detector.calculate_metrics
      
      # 2 filler words out of 13 total = ~15.38%
      expect(metrics[:filler_word_rate]).to be_within(2).of(15.4)
    end
  end
  
  describe 'special pattern detection' do
    context 'slow speaking rate' do
      let(:slow_speech_data) do
        sample_transcript_data.merge(
          words: sample_transcript_data[:words][0..4], # Fewer words
          metadata: sample_transcript_data[:metadata].merge(duration: 10.0) # Longer duration
        )
      end
      
      let(:slow_detector) { described_class.new(slow_speech_data, language: 'en') }
      
      it 'detects slow speaking rate' do
        issues = slow_detector.detect_all_issues
        
        pace_issue = issues.find { |issue| issue[:kind] == 'pace_too_slow' }
        expect(pace_issue).to be_present
        expect(pace_issue[:speaking_rate]).to be < 120
      end
    end
    
    context 'fast speaking rate' do
      let(:fast_rules) do
        test_rules.merge(
          'pace_issues' => [
            {
              pattern: 'speaking_rate_above_180',
              regex: :special_pattern,
              description: 'Speaking rate is too fast',
              tip: 'Try to slow down your speech',
              severity: 'medium'
            }
          ]
        )
      end
      
      let(:fast_speech_data) do
        sample_transcript_data.merge(
          words: sample_transcript_data[:words] * 5, # Many more words
          metadata: sample_transcript_data[:metadata].merge(duration: 5.0) # Shorter duration
        )
      end
      
      before do
        allow(Analysis::Rulepacks).to receive(:load_rules).with('en').and_return(fast_rules)
      end
      
      it 'detects fast speaking rate' do
        fast_detector = described_class.new(fast_speech_data, language: 'en')
        issues = fast_detector.detect_all_issues
        
        pace_issue = issues.find { |issue| issue[:kind] == 'pace_too_fast' }
        expect(pace_issue).to be_present
        expect(pace_issue[:speaking_rate]).to be > 180
      end
    end
    
    context 'long pauses' do
      let(:pause_data) do
        words_with_pause = sample_transcript_data[:words].dup
        # Create a long pause between words 2 and 3
        words_with_pause[2][:end] = 2000
        words_with_pause[3][:start] = 6000 # 4 second pause
        
        sample_transcript_data.merge(words: words_with_pause)
      end
      
      let(:pause_rules) do
        test_rules.merge(
          'pause_issues' => [
            {
              pattern: 'long_pause_over_3s',
              regex: :special_pattern,
              description: 'Long pause detected',
              tip: 'Try to maintain flow in your speech',
              severity: 'low'
            }
          ]
        )
      end
      
      before do
        allow(Analysis::Rulepacks).to receive(:load_rules).with('en').and_return(pause_rules)
      end
      
      it 'detects long pauses' do
        pause_detector = described_class.new(pause_data, language: 'en')
        issues = pause_detector.detect_all_issues
        
        pause_issue = issues.find { |issue| issue[:kind] == 'long_pause' }
        expect(pause_issue).to be_present
        expect(pause_issue[:pause_duration_ms]).to eq(4000)
        expect(pause_issue[:start_ms]).to eq(2000)
        expect(pause_issue[:end_ms]).to eq(6000)
      end
    end
  end
  
  describe 'regex pattern detection' do
    it 'finds word-level matches for timing accuracy' do
      issues = detector.detect_all_issues
      
      um_issue = issues.find { |issue| issue[:matched_words]&.include?('Um,') }
      expect(um_issue).to be_present
      expect(um_issue[:start_ms]).to eq(0) # Start of "Um"
      expect(um_issue[:end_ms]).to eq(500) # End of "Um"
    end
    
    it 'groups nearby matches when appropriate' do
      # This would require setting up transcript data with multiple matches close together
      # For now, we'll test that the grouping logic doesn't break single matches
      issues = detector.detect_all_issues
      
      filler_issues = issues.select { |issue| issue[:kind] == 'filler_word' }
      expect(filler_issues).not_to be_empty
    end
    
    it 'extracts context around matches' do
      issues = detector.detect_all_issues
      
      issue_with_context = issues.first
      expect(issue_with_context[:text]).to include(issue_with_context[:matched_words]&.first || '')
    end
  end
  
  describe 'rate limiting' do
    let(:rate_limited_rules) do
      test_rules.tap do |rules|
        rules['filler_words'][0][:max_matches_per_minute] = 1
      end
    end
    
    before do
      allow(Analysis::Rulepacks).to receive(:load_rules).with('en').and_return(rate_limited_rules)
    end
    
    it 'limits matches per minute when specified' do
      issues = detector.detect_all_issues
      
      filler_issues = issues.select { |issue| issue[:kind] == 'filler_word' }
      # With 7 seconds duration and max 1 per minute, we should get at most 1 issue
      expect(filler_issues.length).to be <= 1
    end
  end
  
  describe 'error handling' do
    context 'with malformed transcript data' do
      let(:empty_detector) { described_class.new({}) }
      
      it 'handles missing transcript gracefully' do
        expect { empty_detector.detect_all_issues }.not_to raise_error
        issues = empty_detector.detect_all_issues
        expect(issues).to be_an(Array)
      end
      
      it 'handles missing words array gracefully' do
        metrics = empty_detector.calculate_metrics
        expect(metrics[:word_count]).to eq(0)
        expect(metrics[:speaking_rate_wpm]).to eq(0)
      end
    end
    
    context 'with invalid rule configuration' do
      let(:broken_rules) do
        {
          'broken_category' => [
            {
              pattern: nil,
              regex: nil,
              description: 'Broken rule'
            }
          ]
        }
      end
      
      before do
        allow(Analysis::Rulepacks).to receive(:load_rules).with('en').and_return(broken_rules)
      end
      
      it 'handles broken rules without crashing' do
        broken_detector = described_class.new(sample_transcript_data, language: 'en')
        expect { broken_detector.detect_all_issues }.not_to raise_error
      end
    end
  end
end