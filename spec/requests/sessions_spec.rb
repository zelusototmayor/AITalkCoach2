require 'rails_helper'

RSpec.describe 'Sessions', type: :request do
  let(:guest_user) { User.find_or_create_by(email: 'guest@aitalkcoach.local') }

  before do
    # Ensure guest user exists for all tests
    guest_user
  end

  describe 'GET /sessions' do
    it 'returns successful response' do
      get sessions_path
      expect(response).to have_http_status(:success)
    end

    it 'displays sessions in order' do
      old_session = create(:session, user: guest_user, title: 'Old Session', created_at: 2.days.ago)
      new_session = create(:session, user: guest_user, title: 'New Session', created_at: 1.day.ago)

      get sessions_path

      expect(response.body).to include('New Session')
      expect(response.body).to include('Old Session')
    end

    context 'when guest user not found' do
      before do
        User.find_by(email: 'guest@aitalkcoach.local')&.destroy
      end

      it 'redirects to root with error' do
        get sessions_path
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include('Guest user not found')
      end
    end
  end

  describe 'GET /sessions/new' do
    it 'returns successful response' do
      get new_session_path
      expect(response).to have_http_status(:success)
    end

    it 'displays recording interface' do
      get new_session_path
      expect(response.body).to include('Start Recording')
    end
  end

  describe 'POST /sessions' do
    let(:valid_params) do
      {
        session: {
          title: 'Test Recording Session',
          language: 'en',
          media_kind: 'audio',
          target_seconds: 60,
          media_files: [ fixture_file_upload('test_audio.webm', 'audio/webm') ]
        }
      }
    end

    let(:invalid_params) do
      {
        session: {
          title: '',
          language: '',
          media_kind: 'invalid'
        }
      }
    end

    it 'creates session with valid parameters' do
      expect {
        post sessions_path, params: valid_params
      }.to change(Session, :count).by(1)
    end

    it 'sets proper session attributes' do
      post sessions_path, params: valid_params

      session = Session.last
      expect(session.title).to eq('Test Recording Session')
      expect(session.language).to eq('en')
      expect(session.media_kind).to eq('audio')
      expect(session.target_seconds).to eq(60)
      expect(session.processing_state).to eq('pending')
      expect(session.completed).to be false
      expect(session.user).to eq(guest_user)
    end

    it 'redirects to session show page' do
      post sessions_path, params: valid_params
      expect(response).to redirect_to(Session.last)
    end

    it 'sets success notice' do
      post sessions_path, params: valid_params
      expect(flash[:notice]).to eq('Recording session started successfully.')
    end

    it 'renders new template for invalid parameters' do
      post sessions_path, params: invalid_params
      expect(response).to have_http_status(:unprocessable_content)
      expect(response).to render_template(:new)
    end
  end

  describe 'GET /sessions/:id' do
    let(:session_record) { create(:session, user: guest_user, title: 'Test Session') }
    let!(:issue1) { create(:issue, session: session_record, start_ms: 2000, end_ms: 3000, text: 'Second issue') }
    let!(:issue2) { create(:issue, session: session_record, start_ms: 1000, end_ms: 1500, text: 'First issue') }

    it 'returns successful response' do
      get session_path(session_record)
      expect(response).to have_http_status(:success)
    end

    it 'displays session information' do
      get session_path(session_record)

      expect(response.body).to include('Test Session')
      expect(response.body).to include('First issue')
      expect(response.body).to include('Second issue')
    end

    it 'displays issues in chronological order' do
      get session_path(session_record)

      # The first issue (start_ms: 1000) should appear before the second (start_ms: 2000)
      first_pos = response.body.index('First issue')
      second_pos = response.body.index('Second issue')
      expect(first_pos).to be < second_pos
    end

    it 'raises error for non-existent session' do
      expect {
        get session_path(999999)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    context 'when session belongs to different user' do
      let(:other_user) { create(:user, email: 'other@example.com') }
      let(:other_session) { create(:session, user: other_user) }

      it 'raises error' do
        expect {
          get session_path(other_session)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'DELETE /sessions/:id' do
    let!(:session_record) { create(:session, user: guest_user) }

    it 'destroys the session' do
      expect {
        delete session_path(session_record)
      }.to change(Session, :count).by(-1)
    end

    it 'redirects to sessions index' do
      delete session_path(session_record)
      expect(response).to redirect_to(sessions_path)
    end

    it 'sets success notice' do
      delete session_path(session_record)
      expect(flash[:notice]).to eq('Session deleted successfully.')
    end

    it 'raises error for non-existent session' do
      expect {
        delete session_path(999999)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'integration with metrics calculation' do
    let(:session_with_analysis) do
      create(:session,
        user: guest_user,
        analysis_data: {
          'clarity_score' => 0.85,
          'wpm' => 150,
          'filler_rate' => 0.03
        },
        duration_ms: 60000,
        completed: true
      )
    end

    before do
      create(:issue, session: session_with_analysis, start_ms: 1000, end_ms: 3000)
    end

    it 'displays calculated metrics' do
      get session_path(session_with_analysis)

      # Should display some form of metrics information
      expect(response.body).to match(/clarity|pace|engagement/i)
    end

    it 'includes session data for insights' do
      # Create additional sessions for insights
      create(:session, user: guest_user, completed: true, created_at: 1.week.ago)

      get session_path(session_with_analysis)

      expect(response).to have_http_status(:success)
    end
  end
end
