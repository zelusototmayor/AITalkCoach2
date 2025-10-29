require 'rails_helper'

RSpec.describe Issue, type: :model do
  describe 'validations' do
    subject { build(:issue) }

    it { should validate_presence_of(:kind) }
    it { should validate_numericality_of(:start_ms).is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:end_ms).is_greater_than(:start_ms) }
    it { should validate_inclusion_of(:source).in_array(%w[rule ai]) }
  end

  describe 'associations' do
    it { should belong_to(:session) }
    it { should have_one(:user).through(:session) }
  end

  describe 'scopes' do
    let!(:filler_issue) { create(:issue, kind: 'filler_word') }
    let!(:pace_issue) { create(:issue, :pace_issue) }
    let!(:rule_issue) { create(:issue, source: 'rule') }
    let!(:ai_issue) { create(:issue, :ai_detected) }

    describe '.by_kind' do
      it 'returns issues of specified kind' do
        expect(Issue.by_kind('filler_word')).to include(filler_issue)
        expect(Issue.by_kind('filler_word')).not_to include(pace_issue)
      end
    end

    describe '.by_source' do
      it 'returns issues from specified source' do
        expect(Issue.by_source('rule')).to include(rule_issue)
        expect(Issue.by_source('ai')).to include(ai_issue)
        expect(Issue.by_source('rule')).not_to include(ai_issue)
      end
    end

    describe '.in_timeframe' do
      let!(:early_issue) { create(:issue, start_ms: 0, end_ms: 1000) }
      let!(:middle_issue) { create(:issue, start_ms: 500, end_ms: 1500) }
      let!(:late_issue) { create(:issue, start_ms: 2000, end_ms: 3000) }

      it 'returns issues within timeframe' do
        issues_in_range = Issue.in_timeframe(400, 1200)
        expect(issues_in_range).to include(early_issue, middle_issue)
        expect(issues_in_range).not_to include(late_issue)
      end
    end
  end

  describe 'factory' do
    it 'creates a valid issue' do
      issue = create(:issue)
      expect(issue).to be_valid
      expect(issue.session).to be_present
    end

    it 'creates an AI-detected issue' do
      issue = create(:issue, :ai_detected)
      expect(issue.source).to eq('ai')
      expect(issue.label_confidence).to eq(0.8)
    end

    it 'creates different kinds of issues' do
      pace_issue = create(:issue, :pace_issue)
      clarity_issue = create(:issue, :clarity_issue)
      volume_issue = create(:issue, :volume_issue)

      expect(pace_issue.kind).to eq('pace_too_fast')
      expect(clarity_issue.kind).to eq('unclear_speech')
      expect(volume_issue.kind).to eq('low_volume')
    end
  end

  describe '#duration_ms' do
    let(:issue) { build(:issue, start_ms: 1000, end_ms: 3500) }

    it 'calculates duration in milliseconds' do
      expect(issue.duration_ms).to eq(2500)
    end
  end

  describe '#duration_seconds' do
    let(:issue) { build(:issue, start_ms: 1000, end_ms: 4000) }

    it 'calculates duration in seconds' do
      expect(issue.duration_seconds).to eq(3.0)
    end
  end

  describe 'validation edge cases' do
    it 'does not allow end_ms to be less than or equal to start_ms' do
      issue = build(:issue, start_ms: 1000, end_ms: 1000)
      expect(issue).not_to be_valid
      expect(issue.errors[:end_ms]).to include('must be greater than 1000')
    end

    it 'does not allow negative start_ms' do
      issue = build(:issue, start_ms: -100)
      expect(issue).not_to be_valid
      expect(issue.errors[:start_ms]).to include('must be greater than or equal to 0')
    end
  end
end
