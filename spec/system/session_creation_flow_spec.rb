require 'rails_helper'

RSpec.describe 'Session Creation Flow', type: :system do
  let(:guest_user) { create(:user, email: 'guest@aitalkcoach.local') }

  before do
    guest_user
    driven_by(:rack_test) # Use rack_test for faster execution without JavaScript
  end

  scenario 'User creates a new session successfully' do
    visit root_path
    
    expect(page).to have_content('AI Talk Coach')
    
    # Navigate to new session page
    click_link 'New Session' # Assumes there's a "New Session" link
    
    expect(page).to have_content('Start Recording')
    
    # Fill in session details
    fill_in 'session_title', with: 'My Practice Session'
    select 'English', from: 'session_language'
    select 'Audio', from: 'session_media_kind'
    fill_in 'session_target_seconds', with: '60'
    
    # Submit the form
    click_button 'Start Recording'
    
    # Should redirect to session show page
    expect(current_path).to match(%r{/sessions/\d+})
    expect(page).to have_content('My Practice Session')
    expect(page).to have_content('Recording session started successfully.')
  end

  scenario 'User views session history' do
    # Create some existing sessions
    old_session = create(:session, user: guest_user, title: 'Old Session', created_at: 2.days.ago)
    new_session = create(:session, user: guest_user, title: 'Recent Session', created_at: 1.hour.ago)
    
    visit sessions_path
    
    expect(page).to have_content('Recent Session')
    expect(page).to have_content('Old Session')
    
    # Sessions should be ordered by creation date (newest first)
    content = page.body
    recent_pos = content.index('Recent Session')
    old_pos = content.index('Old Session')
    expect(recent_pos).to be < old_pos
  end

  scenario 'User views session details with issues' do
    session_with_issues = create(:session, 
      user: guest_user, 
      title: 'Session with Issues',
      completed: true,
      analysis_data: {
        'transcript' => 'Hello, um, this is a test recording.',
        'clarity_score' => 0.8,
        'wpm' => 145
      }
    )
    
    create(:issue, 
      session: session_with_issues,
      kind: 'filler',
      category: 'fluency',
      start_ms: 2000,
      end_ms: 2500,
      text: 'um',
      coaching_note: 'Try to eliminate filler words'
    )
    
    visit session_path(session_with_issues)
    
    expect(page).to have_content('Session with Issues')
    expect(page).to have_content('Hello, um, this is a test recording.')
    expect(page).to have_content('Try to eliminate filler words')
  end

  scenario 'User deletes a session' do
    session_to_delete = create(:session, user: guest_user, title: 'Session to Delete')
    
    visit session_path(session_to_delete)
    
    # Delete the session
    click_button 'Delete Session' # Assumes there's a delete button
    
    expect(current_path).to eq(sessions_path)
    expect(page).to have_content('Session deleted successfully.')
    expect(page).not_to have_content('Session to Delete')
  end

  scenario 'User browses prompt library' do
    visit prompts_path
    
    expect(page).to have_content('Prompt Library')
    
    # Should show different categories
    expect(page).to have_content('presentation')
    expect(page).to have_content('conversation')
    expect(page).to have_content('storytelling')
    
    # Should show specific prompts from the YAML config
    expect(page).to have_content('Elevator Pitch')
    expect(page).to have_content('Meeting Introduction')
  end

  scenario 'User sees adaptive prompts based on speech patterns' do
    # Create sessions with consistent filler word issues
    4.times do |i|
      session = create(:session, 
        user: guest_user, 
        completed: true, 
        created_at: (20 - i).days.ago
      )
      
      # Add filler issues to trigger adaptive prompts (3 out of 4 sessions)
      if i < 3
        create(:issue, session: session, category: 'filler_words')
      end
    end
    
    visit prompts_path
    
    # Should include adaptive/recommended prompts
    expect(page).to have_content('recommended').or have_content('adaptive')
  end
end