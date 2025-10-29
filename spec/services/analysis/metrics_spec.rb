require 'rails_helper'

RSpec.describe Analysis::Metrics do
  let(:sample_transcript_data) do
    {
      transcript: "Hello world this is a test recording with some filler words um yeah.",
      words: [
        { word: "Hello", start: 0, end: 500 },
        { word: "world", start: 600, end: 1000 },
        { word: "this", start: 1100, end: 1400 },
        { word: "is", start: 1500, end: 1700 },
        { word: "a", start: 1800, end: 1900 },
        { word: "test", start: 2000, end: 2400 },
        { word: "recording", start: 2500, end: 3200 },
        { word: "with", start: 3300, end: 3600 },
        { word: "some", start: 3700, end: 4000 },
        { word: "filler", start: 4100, end: 4500 },
        { word: "words", start: 4600, end: 5000 },
        { word: "um", start: 5100, end: 5300 },
        { word: "yeah", start: 5400, end: 5800 }
      ],
      metadata: {
        duration: 6.0,
        confidence: 0.9
      }
    }
  end

  let(:sample_issues) do
    [
      { kind: 'filler_word', severity: 'medium' },
      { kind: 'articulation', severity: 'low' }
    ]
  end

  let(:metrics_service) { described_class.new(sample_transcript_data, sample_issues) }

  describe '#initialize' do
    it 'sets up metrics calculator with transcript data' do
      expect(metrics_service.instance_variable_get(:@transcript_data)).to eq(sample_transcript_data)
      expect(metrics_service.instance_variable_get(:@issues)).to eq(sample_issues)
    end

    it 'defaults to English language' do
      service = described_class.new(sample_transcript_data)
      expect(service.instance_variable_get(:@language)).to eq('en')
    end
  end

  describe '#calculate_all_metrics' do
    it 'returns comprehensive metrics structure' do
      metrics = metrics_service.calculate_all_metrics

      expect(metrics).to have_key(:basic_metrics)
      expect(metrics).to have_key(:speaking_metrics)
      expect(metrics).to have_key(:clarity_metrics)
      expect(metrics).to have_key(:fluency_metrics)
      expect(metrics).to have_key(:engagement_metrics)
      expect(metrics).to have_key(:overall_scores)
      expect(metrics).to have_key(:metadata)
    end

    it 'includes calculation metadata' do
      metrics = metrics_service.calculate_all_metrics

      expect(metrics[:metadata]).to have_key(:calculation_time)
      expect(metrics[:metadata]).to have_key(:transcript_quality)
      expect(metrics[:metadata]).to have_key(:confidence_level)
    end
  end

  describe '#calculate_basic_metrics' do
    it 'calculates word-based metrics' do
      metrics = metrics_service.calculate_basic_metrics

      expect(metrics[:word_count]).to eq(13)
      expect(metrics[:unique_word_count]).to be <= 13
      expect(metrics[:duration_ms]).to eq(6000)
      expect(metrics[:duration_seconds]).to eq(6.0)
    end

    it 'calculates speaking and pause times' do
      metrics = metrics_service.calculate_basic_metrics

      expect(metrics).to have_key(:speaking_time_ms)
      expect(metrics).to have_key(:pause_time_ms)
      expect(metrics[:speaking_time_ms]).to be > 0
      expect(metrics[:pause_time_ms]).to be >= 0
    end

    it 'estimates syllable count' do
      metrics = metrics_service.calculate_basic_metrics

      expect(metrics[:syllable_count]).to be > 0
    end
  end

  describe '#calculate_speaking_metrics' do
    it 'calculates words per minute correctly' do
      metrics = metrics_service.calculate_speaking_metrics

      # 13 words in 6 seconds = 130 WPM
      expected_wpm = (13.0 / (6.0 / 60.0))
      expect(metrics[:words_per_minute]).to be_within(1).of(expected_wpm)
    end

    it 'assesses speaking rate' do
      metrics = metrics_service.calculate_speaking_metrics

      expect(metrics[:speaking_rate_assessment]).to be_in([ 'too_slow', 'slow', 'optimal', 'fast', 'too_fast' ])
    end

    it 'calculates pace consistency' do
      metrics = metrics_service.calculate_speaking_metrics

      expect(metrics[:pace_consistency]).to be_between(0, 100)
    end

    it 'handles empty words gracefully' do
      empty_service = described_class.new({ words: [], metadata: { duration: 0 } })
      metrics = empty_service.calculate_speaking_metrics

      expect(metrics[:words_per_minute]).to eq(0)
      expect(metrics[:speaking_rate_assessment]).to eq('unknown')
    end
  end

  describe '#calculate_clarity_metrics' do
    it 'returns comprehensive clarity assessment' do
      metrics = metrics_service.calculate_clarity_metrics

      expect(metrics).to have_key(:clarity_score)
      expect(metrics).to have_key(:filler_metrics)
      expect(metrics).to have_key(:pause_metrics)
      expect(metrics).to have_key(:articulation_score)

      expect(metrics[:clarity_score]).to be_between(0, 100)
    end

    it 'detects filler words in transcript' do
      metrics = metrics_service.calculate_clarity_metrics
      filler_metrics = metrics[:filler_metrics]

      expect(filler_metrics[:total_filler_count]).to be > 0
      expect(filler_metrics[:filler_rate_percentage]).to be > 0
      expect(filler_metrics[:filler_breakdown]).to be_a(Hash)
    end

    it 'analyzes pause patterns' do
      metrics = metrics_service.calculate_clarity_metrics
      pause_metrics = metrics[:pause_metrics]

      expect(pause_metrics[:total_pause_count]).to be >= 0
      expect(pause_metrics[:pause_quality_score]).to be_between(0, 100)
    end
  end

  describe '#calculate_fluency_metrics' do
    it 'measures speech fluency factors' do
      metrics = metrics_service.calculate_fluency_metrics

      expect(metrics).to have_key(:fluency_score)
      expect(metrics).to have_key(:hesitation_count)
      expect(metrics).to have_key(:speech_smoothness)

      expect(metrics[:fluency_score]).to be_between(0, 100)
      expect(metrics[:hesitation_count]).to be >= 0
    end
  end

  describe '#calculate_engagement_metrics' do
    it 'assesses speaker engagement' do
      metrics = metrics_service.calculate_engagement_metrics

      expect(metrics).to have_key(:energy_level)
      expect(metrics).to have_key(:engagement_score)
      expect(metrics).to have_key(:question_usage)

      expect(metrics[:energy_level]).to be_between(0, 100)
      expect(metrics[:engagement_score]).to be_between(0, 100)
    end
  end

  describe '#calculate_overall_scores' do
    it 'provides weighted overall assessment' do
      scores = metrics_service.calculate_overall_scores

      expect(scores).to have_key(:overall_score)
      expect(scores).to have_key(:component_scores)
      expect(scores).to have_key(:grade)
      expect(scores).to have_key(:strengths)
      expect(scores).to have_key(:areas_for_improvement)

      expect(scores[:overall_score]).to be_between(0, 100)
      expect(scores[:grade]).to be_in([ 'A', 'B', 'C', 'D', 'F' ])
    end

    it 'identifies strengths and improvement areas' do
      scores = metrics_service.calculate_overall_scores

      expect(scores[:strengths]).to be_an(Array)
      expect(scores[:areas_for_improvement]).to be_an(Array)
    end
  end

  describe 'error handling' do
    context 'with malformed data' do
      let(:bad_data) { { transcript: nil, words: nil } }
      let(:bad_service) { described_class.new(bad_data) }

      it 'handles missing transcript gracefully' do
        expect { bad_service.calculate_basic_metrics }.not_to raise_error
      end

      it 'raises MetricsError for calculation failures' do
        allow(bad_service).to receive(:extract_words).and_raise(StandardError.new('Test error'))

        expect { bad_service.calculate_all_metrics }
          .to raise_error(Analysis::Metrics::MetricsError, /Failed to calculate metrics/)
      end
    end
  end

  describe 'constants and ranges' do
    it 'defines optimal WPM range' do
      expect(described_class::OPTIMAL_WPM_RANGE).to eq(140..160)
      expect(described_class::ACCEPTABLE_WPM_RANGE).to eq(120..180)
    end

    it 'defines clarity scoring weights' do
      weights = described_class::CLARITY_WEIGHTS
      expect(weights.values.sum).to be_within(0.01).of(1.0)
    end
  end
end
