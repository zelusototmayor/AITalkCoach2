require 'rails_helper'

RSpec.describe Session, type: :model do
  describe 'validations' do
    subject { build(:session) }

    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:language) }
    it { should validate_inclusion_of(:media_kind).in_array(%w[audio video]) }
    it { should validate_inclusion_of(:processing_state).in_array(%w[pending processing completed failed]) }
  end

  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_many(:issues).dependent(:destroy) }
    it { should have_many_attached(:media_files) }
  end

  describe 'scopes' do
    let!(:completed_session) { create(:session, :completed) }
    let!(:failed_session) { create(:session, :failed) }
    let!(:pending_session) { create(:session) }

    describe '.completed' do
      it 'returns only completed sessions' do
        expect(Session.completed).to include(completed_session)
        expect(Session.completed).not_to include(failed_session, pending_session)
      end
    end

    describe '.failed' do
      it 'returns only failed sessions' do
        expect(Session.failed).to include(failed_session)
        expect(Session.failed).not_to include(completed_session, pending_session)
      end
    end
  end

  describe 'factory' do
    it 'creates a valid session' do
      session = create(:session)
      expect(session).to be_valid
      expect(session.user).to be_present
    end

    it 'creates a completed session' do
      session = create(:session, :completed)
      expect(session.completed).to be true
      expect(session.processing_state).to eq('completed')
    end

    it 'creates a failed session' do
      session = create(:session, :failed)
      expect(session.completed).to be false
      expect(session.incomplete_reason).to eq('Processing failed')
    end

    it 'creates a session with issues' do
      session = create(:session, :with_issues)
      expect(session.issues.count).to eq(2)
    end
  end

  describe '#analysis_data' do
    context 'with valid JSON' do
      let(:session) { create(:session, :completed) }

      it 'returns parsed analysis data' do
        data = session.analysis_data
        expect(data).to be_a(Hash)
        expect(data['wpm']).to eq(120)
        expect(data['clarity_score']).to eq(0.85)
      end
    end

    context 'with invalid JSON' do
      let(:session) { create(:session, analysis_json: 'invalid json') }

      it 'returns empty hash' do
        expect(session.analysis_data).to eq({})
      end
    end

    context 'with no analysis data' do
      let(:session) { create(:session) }

      it 'returns empty hash' do
        expect(session.analysis_data).to eq({})
      end
    end
  end

  describe '#analysis_data=' do
    let(:session) { create(:session) }
    let(:data) { { wpm: 100, clarity_score: 0.9 } }

    it 'sets analysis_json as JSON string' do
      session.analysis_data = data
      expect(session.analysis_json).to eq(data.to_json)
    end
  end
end
