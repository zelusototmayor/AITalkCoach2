require 'rails_helper'
require 'benchmark'

RSpec.describe 'Analysis Pipeline Performance', type: :performance do
  let(:guest_user) { create(:user, email: 'guest@aitalkcoach.local') }

  describe 'Rule-based analysis performance' do
    it 'processes rules efficiently for typical session sizes' do
      session = create(:session, user: guest_user, duration_ms: 120000) # 2 minutes

      # Create a realistic transcript size (approximately 300 words for 2 minutes)
      transcript_segments = (1..300).map do |i|
        {
          'start_ms' => i * 400,
          'end_ms' => (i + 1) * 400,
          'text' => "This is segment number #{i} with some filler words um like you know."
        }
      end

      time_taken = Benchmark.realtime do
        # Test rule detection performance
        transcript_segments.each do |segment|
          transcript_data = {
            transcript: segment['text'],
            words: [],
            metadata: { duration: 1.0 }
          }
          detector = Analysis::RuleDetector.new(transcript_data, language: 'en')
          issues = detector.detect_all_issues
        end
      end

      # Should process 300 segments in under 1 second
      expect(time_taken).to be < 1.0
    end

    it 'handles large vocabulary rule sets efficiently' do
      # Test with multiple languages and large rule sets
      languages = [ 'en', 'pt' ]

      languages.each do |language|
        time_taken = Benchmark.realtime do
          # Process 100 different text samples
          100.times do |i|
            text = "Sample text number #{i} with um various uh speaking patterns like you know and stuff."
            transcript_data = {
              transcript: text,
              words: [],
              metadata: { duration: 1.0 }
            }
            detector = Analysis::RuleDetector.new(transcript_data, language: language)
            issues = detector.detect_all_issues
          end
        end

        # Should handle 100 detections per language in under 0.5 seconds
        expect(time_taken).to be < 0.5
      end
    end

    it 'maintains consistent performance with repeated calls' do
      text_sample = "This is a um test with like some you know filler words and stuff."
      transcript_data = {
        transcript: text_sample,
        words: [],
        metadata: { duration: 1.0 }
      }
      detector = Analysis::RuleDetector.new(transcript_data, language: 'en')

      times = []

      # Run 50 iterations to test consistency
      50.times do
        time_taken = Benchmark.realtime do
          issues = detector.detect_all_issues
        end
        times << time_taken
      end

      # Performance should be consistent (standard deviation low)
      mean_time = times.sum / times.length
      variance = times.map { |t| (t - mean_time) ** 2 }.sum / times.length
      std_deviation = Math.sqrt(variance)

      # Standard deviation should be less than 20% of mean time
      expect(std_deviation).to be < (mean_time * 0.2)

      # No single call should take more than 10x the mean
      expect(times.max).to be < (mean_time * 10)
    end
  end

  describe 'Metrics calculation performance' do
    it 'calculates WPM efficiently for long transcripts' do
      # Create a long transcript (1000 words)
      long_transcript = (1..1000).map { |i| "word#{i}" }.join(' ')
      session_data = {
        'transcript' => long_transcript,
        'segments' => (1..1000).map do |i|
          {
            'start_ms' => i * 100,
            'end_ms' => (i + 1) * 100,
            'text' => "word#{i}"
          }
        end
      }

      time_taken = Benchmark.realtime do
        metrics = Analysis::Metrics.new(session_data)
        wpm = metrics.calculate_wpm
        filler_rate = metrics.calculate_filler_rate([ 'um', 'uh', 'like' ])
        clarity_score = metrics.calculate_clarity_score([])
      end

      # Should calculate all metrics for 1000 words in under 0.1 seconds
      expect(time_taken).to be < 0.1
    end

    it 'handles empty or malformed data gracefully' do
      test_cases = [
        {},
        { 'transcript' => '' },
        { 'transcript' => nil },
        { 'segments' => [] },
        { 'segments' => nil }
      ]

      test_cases.each do |session_data|
        time_taken = Benchmark.realtime do
          expect {
            metrics = Analysis::Metrics.new(session_data)
            metrics.calculate_wpm
            metrics.calculate_filler_rate([ 'um' ])
            metrics.calculate_clarity_score([])
          }.not_to raise_error
        end

        # Should handle edge cases quickly
        expect(time_taken).to be < 0.01
      end
    end
  end

  describe 'Memory usage patterns' do
    it 'does not leak memory during repeated analysis' do
      # This is a basic memory leak detection test
      # In a real application, you might use more sophisticated tools

      initial_objects = ObjectSpace.count_objects

      # Process many sessions to check for memory growth
      20.times do |i|
        session_data = {
          'transcript' => "This is session #{i} with some um filler words.",
          'segments' => [
            {
              'start_ms' => 0,
              'end_ms' => 1000,
              'text' => "This is session #{i} with some um filler words."
            }
          ]
        }

        # Create and process metrics
        metrics = Analysis::Metrics.new(session_data)
        metrics.calculate_wpm
        metrics.calculate_filler_rate([ 'um' ])

        # Create and use rule detector
        transcript_data = {
          transcript: "Session #{i} text",
          words: [],
          metadata: { duration: 1.0 }
        }
        detector = Analysis::RuleDetector.new(transcript_data, language: 'en')
        detector.detect_all_issues
      end

      # Force garbage collection
      GC.start

      final_objects = ObjectSpace.count_objects

      # Object count shouldn't grow dramatically (allow some growth for caching)
      object_growth_ratio = final_objects[:TOTAL].to_f / initial_objects[:TOTAL]
      expect(object_growth_ratio).to be < 1.5 # Allow up to 50% growth
    end
  end

  describe 'Concurrent processing simulation' do
    it 'handles multiple sessions being processed simultaneously' do
      sessions = 5.times.map do |i|
        create(:session, user: guest_user, title: "Concurrent Session #{i}")
      end

      time_taken = Benchmark.realtime do
        threads = sessions.map do |session|
          Thread.new do
            # Simulate analysis processing
            text = "This is concurrent session processing with um some filler words."

            10.times do |j|
              transcript_data = {
                transcript: "#{text} Iteration #{j}",
                words: [],
                metadata: { duration: 1.0 }
              }
              detector = Analysis::RuleDetector.new(transcript_data, language: 'en')
              issues = detector.detect_all_issues
            end

            # Simulate metrics calculation
            session_data = {
              'transcript' => text * 10,
              'segments' => 10.times.map { |k| { 'start_ms' => k * 1000, 'end_ms' => (k + 1) * 1000, 'text' => text } }
            }

            metrics = Analysis::Metrics.new(session_data)
            metrics.calculate_wpm
            metrics.calculate_filler_rate([ 'um', 'uh' ])
          end
        end

        threads.each(&:join)
      end

      # 5 concurrent sessions should complete in under 2 seconds
      expect(time_taken).to be < 2.0
    end
  end

  describe 'Database query performance' do
    it 'efficiently queries sessions with issues for insights' do
      # Create multiple sessions with issues
      10.times do |i|
        session = create(:session,
          user: guest_user,
          completed: true,
          created_at: i.days.ago,
          analysis_data: {
            'clarity_score' => 0.8,
            'wpm' => 150,
            'filler_rate' => 0.05
          }
        )

        # Create multiple issues per session
        5.times do |j|
          create(:issue,
            session: session,
            kind: [ 'filler_word', 'pace_too_fast', 'unclear_speech' ].sample,
            start_ms: j * 1000,
            end_ms: (j + 1) * 1000
          )
        end
      end

      time_taken = Benchmark.realtime do
        # Simulate the query used in sessions controller for insights
        user_sessions = guest_user.sessions
          .where(completed: true)
          .where('created_at >= ?', 90.days.ago)
          .includes(:issues)
          .order(:created_at)
          .limit(50)

        # Process the data as would happen in the controller
        user_sessions.each do |session|
          issues_count = session.issues.count
          total_duration = session.issues.sum { |issue| issue.end_ms - issue.start_ms }
        end
      end

      # Query with 10 sessions, 50 total issues should complete quickly
      expect(time_taken).to be < 0.1
    end

    it 'efficiently handles user weakness analysis queries' do
      # Create sessions for weakness analysis (as done in prompts controller)
      20.times do |i|
        session = create(:session,
          user: guest_user,
          completed: true,
          created_at: i.days.ago,
          analysis_data: {
            'wpm' => [ 100, 150, 200 ].sample,
            'clarity_score' => [ 0.5, 0.7, 0.9 ].sample,
            'filler_rate' => [ 0.02, 0.05, 0.1 ].sample
          }
        )

        # Some sessions have issues
        if i < 15
          create(:issue, session: session, kind: 'filler_word')
        end
      end

      time_taken = Benchmark.realtime do
        # Simulate the weakness analysis query from prompts controller
        recent_sessions = guest_user.sessions
          .where(completed: true)
          .where('created_at >= ?', 30.days.ago)
          .includes(:issues)

        # Analyze patterns as done in the controller
        session_count = recent_sessions.count.to_f

        # Filler analysis
        filler_sessions = recent_sessions.select do |session|
          session.issues.any? { |issue| issue.kind == 'filler_word' }
        end

        # Pace analysis
        pace_sessions = recent_sessions.select do |session|
          wpm = session.analysis_data['wpm']
          wpm && (wpm < 120 || wpm > 200)
        end

        # Clarity analysis
        clarity_sessions = recent_sessions.select do |session|
          clarity = session.analysis_data['clarity_score']
          clarity && clarity < 0.7
        end
      end

      # Complex weakness analysis should complete quickly
      expect(time_taken).to be < 0.2
    end
  end

  describe 'Edge case performance' do
    it 'handles very short sessions efficiently' do
      session_data = {
        'transcript' => 'Hi.',
        'segments' => [ { 'start_ms' => 0, 'end_ms' => 500, 'text' => 'Hi.' } ]
      }

      time_taken = Benchmark.realtime do
        100.times do
          metrics = Analysis::Metrics.new(session_data)
          metrics.calculate_wpm

          transcript_data = {
            transcript: 'Hi.',
            words: [],
            metadata: { duration: 0.5 }
          }
          detector = Analysis::RuleDetector.new(transcript_data, language: 'en')
          detector.detect_all_issues
        end
      end

      # 100 very short sessions should process quickly
      expect(time_taken).to be < 0.1
    end

    it 'handles very long sessions efficiently' do
      # Create a very long transcript (5000 words, ~30 minutes)
      long_text = (1..5000).map { |i| "word#{i}" }.join(' ')
      session_data = {
        'transcript' => long_text,
        'segments' => (1..5000).map do |i|
          {
            'start_ms' => i * 360, # 360ms per word for ~30min total
            'end_ms' => (i + 1) * 360,
            'text' => "word#{i}"
          }
        end
      }

      time_taken = Benchmark.realtime do
        metrics = Analysis::Metrics.new(session_data)
        wpm = metrics.calculate_wpm
        filler_rate = metrics.calculate_filler_rate([ 'um', 'uh', 'like', 'you', 'know' ])
        clarity_score = metrics.calculate_clarity_score([])

        # Only test rule detection on a subset to avoid very long test times
        sample_text = session_data['segments'].first(100).map { |s| s['text'] }.join(' ')
        transcript_data = {
          transcript: sample_text,
          words: [],
          metadata: { duration: 36.0 }
        }
        detector = Analysis::RuleDetector.new(transcript_data, language: 'en')
        issues = detector.detect_all_issues
      end

      # Long session analysis should complete in reasonable time
      expect(time_taken).to be < 5.0
    end
  end
end
