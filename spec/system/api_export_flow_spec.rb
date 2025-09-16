require 'rails_helper'

RSpec.describe 'API Export Flow', type: :system do
  let(:guest_user) { create(:user, email: 'guest@aitalkcoach.local') }
  
  before do
    guest_user
    driven_by(:rack_test)
  end

  scenario 'User exports session data as JSON' do
    session_with_data = create(:session,
      user: guest_user,
      title: 'Export Test Session',
      language: 'en',
      duration_ms: 90000,
      analysis_data: {
        'transcript' => 'Hello world, this is a test recording.',
        'clarity_score' => 0.85,
        'wpm' => 140
      },
      completed: true
    )

    create(:issue,
      session: session_with_data,
      kind: 'filler',
      category: 'fluency',
      start_ms: 5000,
      end_ms: 6000,
      text: 'um, you know',
      coaching_note: 'Try pausing instead of using filler words'
    )

    # Simulate API call for JSON export
    visit export_api_session_path(session_with_data, format: :json)
    
    # Should return JSON data
    json_response = JSON.parse(page.body)
    
    expect(json_response['session']['title']).to eq('Export Test Session')
    expect(json_response['analysis']['clarity_score']).to eq(0.85)
    expect(json_response['issues']).to be_an(Array)
    expect(json_response['issues'].first['text']).to eq('um, you know')
  end

  scenario 'User exports session data as text transcript' do
    session_with_data = create(:session,
      user: guest_user,
      title: 'Transcript Export Session',
      language: 'en',
      duration_ms: 75000,
      analysis_data: { 'transcript' => 'This is the transcript content.' },
      created_at: Time.zone.parse('2024-01-15 14:30:00'),
      completed: true
    )

    create(:issue,
      session: session_with_data,
      category: 'fluency',
      start_ms: 5000,
      end_ms: 6000,
      text: 'um, you know',
      coaching_note: 'Reduce filler words'
    )

    # Simulate API call for text export
    visit export_api_session_path(session_with_data, format: :txt)
    
    content = page.body
    
    expect(content).to include('Transcript Export Session')
    expect(content).to include('Language: EN')
    expect(content).to include('Duration: 01:15')
    expect(content).to include('This is the transcript content.')
    expect(content).to include('SPEECH ANALYSIS ISSUES')
    expect(content).to include('[00:05] "um, you know"')
    expect(content).to include('💡 Reduce filler words')
  end

  scenario 'User gets timeline data for session visualization' do
    session_record = create(:session, user: guest_user, duration_ms: 120000)
    
    create(:issue, session: session_record, start_ms: 1000, end_ms: 2000, text: 'First issue', kind: 'filler')
    create(:issue, session: session_record, start_ms: 3000, end_ms: 4000, text: 'Second issue', kind: 'pace')
    
    # Simulate API call for timeline data
    visit timeline_api_session_path(session_record)
    
    json_response = JSON.parse(page.body)
    
    expect(json_response['session_id']).to eq(session_record.id)
    expect(json_response['duration_ms']).to eq(120000)
    expect(json_response['issues']).to be_an(Array)
    expect(json_response['issues'].length).to eq(2)
    
    # Issues should be ordered by start time
    expect(json_response['issues'].first['start_ms']).to eq(1000)
    expect(json_response['issues'].second['start_ms']).to eq(3000)
  end

  scenario 'User requests AI reprocessing for completed session' do
    completed_session = create(:session, user: guest_user, completed: true)
    
    # Simulate API call for reprocessing (would normally be AJAX)
    page.driver.post reprocess_ai_api_session_path(completed_session)
    
    # Check response status and content
    expect(page.status_code).to eq(202) # Accepted
    
    json_response = JSON.parse(page.body)
    expect(json_response['message']).to eq('AI reprocessing started')
    expect(json_response['session_id']).to eq(completed_session.id)
  end

  scenario 'User cannot reprocess incomplete session' do
    incomplete_session = create(:session, user: guest_user, completed: false)
    
    # Simulate API call for reprocessing
    page.driver.post reprocess_ai_api_session_path(incomplete_session)
    
    # Should return error status
    expect(page.status_code).to eq(422) # Unprocessable Entity
    
    json_response = JSON.parse(page.body)
    expect(json_response['error']).to eq('Session must be completed before reprocessing')
  end

  scenario 'User cannot access other users sessions' do
    other_user = create(:user, email: 'other@example.com')
    other_session = create(:session, user: other_user)
    
    # Try to access other user's session timeline
    visit timeline_api_session_path(other_session)
    
    expect(page.status_code).to eq(403) # Forbidden
    
    json_response = JSON.parse(page.body)
    expect(json_response['error']).to eq('Access denied')
  end

  scenario 'System handles missing sessions gracefully' do
    # Try to access non-existent session
    expect {
      visit timeline_api_session_path(999999)
    }.to raise_error(ActiveRecord::RecordNotFound)
  end
end