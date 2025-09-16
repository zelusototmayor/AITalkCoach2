require 'rails_helper'

RSpec.describe 'API Sessions', type: :request do
  let(:guest_user) { User.find_or_create_by(email: 'guest@aitalkcoach.local') }
  let(:other_user) { create(:user, email: 'other@example.com') }

  before do
    # Ensure guest user exists for all tests
    guest_user
  end

  describe 'GET /api/sessions/:id/timeline' do
    let(:session_record) { create(:session, user: guest_user, duration_ms: 120000) }
    let!(:issue1) { create(:issue, session: session_record, start_ms: 2000, end_ms: 3000, text: 'Second issue') }
    let!(:issue2) { create(:issue, session: session_record, start_ms: 1000, end_ms: 2000, text: 'First issue') }

    it 'returns JSON timeline data' do
      get timeline_api_session_path(session_record)
      
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include('application/json')
      
      json_response = JSON.parse(response.body)
      expect(json_response['session_id']).to eq(session_record.id)
      expect(json_response['duration_ms']).to eq(120000)
      expect(json_response['issues']).to be_an(Array)
      expect(json_response['issues'].length).to eq(2)
    end

    it 'orders issues by start time' do
      get timeline_api_session_path(session_record)
      
      json_response = JSON.parse(response.body)
      issues = json_response['issues']
      
      expect(issues.first['start_ms']).to eq(1000)
      expect(issues.second['start_ms']).to eq(2000)
      expect(issues.first['text']).to eq('First issue')
      expect(issues.second['text']).to eq('Second issue')
    end

    it 'includes complete issue data' do
      get timeline_api_session_path(session_record)
      
      json_response = JSON.parse(response.body)
      issue_data = json_response['issues'].first
      
      expect(issue_data.keys).to include('id', 'kind', 'start_ms', 'end_ms', 'text', 'confidence', 'source')
    end

    context 'when session belongs to different user' do
      let(:other_session) { create(:session, user: other_user) }

      it 'returns forbidden error' do
        get timeline_api_session_path(other_session)
        
        expect(response).to have_http_status(:forbidden)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Access denied')
      end
    end

    context 'when guest user not found' do
      before do
        User.find_by(email: 'guest@aitalkcoach.local')&.destroy
      end

      it 'returns unauthorized error' do
        get timeline_api_session_path(session_record)
        
        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Guest user not found')
      end
    end

    it 'raises error for non-existent session' do
      expect {
        get timeline_api_session_path(999999)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'GET /api/sessions/:id/export' do
    let(:session_with_data) do
      create(:session,
        user: guest_user,
        title: 'Export Test Session',
        language: 'en',
        duration_ms: 90000,
        analysis_data: {
          'transcript' => 'Hello world, this is a test recording.',
          'clarity_score' => 0.85,
          'wpm' => 140,
          'filler_rate' => 0.02
        },
        completed: true,
        created_at: Time.zone.parse('2024-01-15 14:30:00')
      )
    end

    before do
      create(:issue,
        session: session_with_data,
        kind: 'filler',
        category: 'fluency',
        start_ms: 5000,
        end_ms: 6000,
        text: 'um, you know',
        rationale: 'Filler words detected in speech',
        coaching_note: 'Try pausing instead of using filler words',
        rewrite: 'pause briefly',
        tip: 'Practice speaking more slowly',
        label_confidence: 0.9,
        severity: 'low'
      )

      create(:issue,
        session: session_with_data,
        kind: 'pace',
        category: 'pacing',
        start_ms: 15000,
        end_ms: 18000,
        text: 'speaking too fast here',
        coaching_note: 'Slow down for better comprehension',
        severity: 'medium'
      )
    end

    context 'JSON format' do
      it 'returns complete export data' do
        get export_api_session_path(session_with_data, format: :json)
        
        expect(response).to have_http_status(:success)
        expect(response.content_type).to include('application/json')
        
        json_response = JSON.parse(response.body)
        
        # Verify session data
        expect(json_response['session']['id']).to eq(session_with_data.id)
        expect(json_response['session']['title']).to eq('Export Test Session')
        expect(json_response['session']['language']).to eq('en')
        expect(json_response['session']['duration_ms']).to eq(90000)
        
        # Verify analysis data
        expect(json_response['analysis']['clarity_score']).to eq(0.85)
        expect(json_response['analysis']['wpm']).to eq(140)
        expect(json_response['analysis']['transcript']).to eq('Hello world, this is a test recording.')
        
        # Verify issues data
        expect(json_response['issues']).to be_an(Array)
        expect(json_response['issues'].length).to eq(2)
        
        filler_issue = json_response['issues'].find { |i| i['kind'] == 'filler' }
        expect(filler_issue['text']).to eq('um, you know')
        expect(filler_issue['coaching_note']).to eq('Try pausing instead of using filler words')
        expect(filler_issue['confidence']).to eq(0.9)
      end
    end

    context 'TXT format' do
      it 'returns formatted transcript' do
        get export_api_session_path(session_with_data, format: :txt)
        
        expect(response).to have_http_status(:success)
        expect(response.content_type).to include('text/plain')
        
        content = response.body
        
        # Check header information
        expect(content).to include('Export Test Session')
        expect(content).to include('Language: EN')
        expect(content).to include('Duration: 01:30')
        expect(content).to include('January 15, 2024')
        expect(content).to include('Issues Found: 2')
        
        # Check transcript content
        expect(content).to include('Hello world, this is a test recording.')
        
        # Check issues section
        expect(content).to include('SPEECH ANALYSIS ISSUES')
        expect(content).to include('FLUENCY (1)')
        expect(content).to include('PACING (1)')
        expect(content).to include('[00:05] "um, you know"')
        expect(content).to include('💡 Try pausing instead of using filler words')
        expect(content).to include('[00:15] "speaking too fast here"')
      end

      it 'handles sessions without transcript' do
        session_no_transcript = create(:session,
          user: guest_user,
          title: 'No Transcript Session',
          analysis_data: {}
        )

        get export_api_session_path(session_no_transcript, format: :txt)
        
        expect(response).to have_http_status(:success)
        content = response.body
        expect(content).to include('No Transcript Session')
        expect(content).to include('No transcript available')
      end
    end

    context 'CSV format' do
      it 'returns CSV with proper structure' do
        get export_api_session_path(session_with_data, format: :csv)
        
        expect(response).to have_http_status(:success)
        expect(response.content_type).to include('text/csv')
        
        # Check filename in headers
        expect(response.headers['Content-Disposition']).to include('export-test-session-analysis.csv')
        
        csv_content = response.body
        lines = csv_content.split("\n")
        
        # Check headers
        headers = lines.first
        expect(headers).to include('Timestamp,Category,Issue Text,Coaching Note,Suggested Rewrite,Confidence,Severity')
        
        # Check data rows
        expect(lines.length).to be >= 3 # Header + 2 issues
        
        # Find filler issue row
        filler_row = lines.find { |line| line.include?('um, you know') }
        expect(filler_row).to include('00:05')
        expect(filler_row).to include('Fluency')
        expect(filler_row).to include('Try pausing instead of using filler words')
        expect(filler_row).to include('0.9')
      end
    end

    context 'when session belongs to different user' do
      let(:other_session) { create(:session, user: other_user) }

      it 'returns forbidden error' do
        get export_api_session_path(other_session, format: :json)
        
        expect(response).to have_http_status(:forbidden)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Access denied')
      end
    end
  end

  describe 'POST /api/sessions/:id/reprocess_ai' do
    context 'when session is completed' do
      let(:completed_session) { create(:session, user: guest_user, completed: true) }

      it 'accepts reprocessing request' do
        post reprocess_ai_api_session_path(completed_session)
        
        expect(response).to have_http_status(:accepted)
        
        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('AI reprocessing started')
        expect(json_response['session_id']).to eq(completed_session.id)
      end
    end

    context 'when session is not completed' do
      let(:incomplete_session) { create(:session, user: guest_user, completed: false) }

      it 'returns unprocessable entity error' do
        post reprocess_ai_api_session_path(incomplete_session)
        
        expect(response).to have_http_status(:unprocessable_content)
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Session must be completed before reprocessing')
      end
    end

    context 'when session belongs to different user' do
      let(:other_session) { create(:session, user: other_user, completed: true) }

      it 'returns forbidden error' do
        post reprocess_ai_api_session_path(other_session)
        
        expect(response).to have_http_status(:forbidden)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Access denied')
      end
    end

    context 'when guest user not found' do
      before do
        User.find_by(email: 'guest@aitalkcoach.local')&.destroy
      end

      it 'returns unauthorized error' do
        incomplete_session = create(:session, user: guest_user, completed: false)
        
        post reprocess_ai_api_session_path(incomplete_session)
        
        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Guest user not found')
      end
    end
  end
end