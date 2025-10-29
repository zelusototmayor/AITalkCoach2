require 'rails_helper'

RSpec.describe 'Adaptive Prompts Flow', type: :system do
  let(:guest_user) { create(:user, email: 'guest@aitalkcoach.local') }

  before do
    guest_user
    driven_by(:rack_test)
  end

  scenario 'New user sees only base prompts' do
    # User with no session history
    visit prompts_path

    expect(page).to have_content('Prompt Library')

    # Should show base prompt categories
    expect(page).to have_content('presentation')
    expect(page).to have_content('conversation')
    expect(page).to have_content('storytelling')

    # Should show base prompts
    expect(page).to have_content('Elevator Pitch')
    expect(page).to have_content('Meeting Introduction')

    # Should not show adaptive prompts yet
    expect(page).not_to have_content('Filler-Free Explanation')
    expect(page).not_to have_content('Paced Explanation')
  end

  scenario 'User with insufficient sessions sees only base prompts' do
    # Create only 2 sessions (below 3 session minimum)
    2.times do |i|
      create(:session, user: guest_user, completed: true, created_at: (10 - i).days.ago)
    end

    visit prompts_path

    # Should still show only base prompts
    expect(page).to have_content('Elevator Pitch')
    expect(page).not_to have_content('recommended')
  end

  scenario 'User with filler word patterns sees adaptive prompts' do
    # Create 4 sessions with filler word issues in 3 of them
    4.times do |i|
      session = create(:session, user: guest_user, completed: true, created_at: (20 - i).days.ago)

      if i < 3  # 75% of sessions have filler issues (above 40% threshold)
        create(:issue, session: session, category: 'filler_words')
      end
    end

    visit prompts_path

    # Should now show adaptive/recommended section
    expect(page).to have_content('recommended').or have_content('adaptive')

    # Should include filler-focused prompts
    expect(page).to have_content('Filler').or have_content('fluency')
  end

  scenario 'User with pace issues sees pace-focused adaptive prompts' do
    # Create sessions with pacing problems
    4.times do |i|
      create(:session,
        user: guest_user,
        completed: true,
        created_at: (20 - i).days.ago,
        analysis_data: {
          'wpm' => i < 3 ? 80 : 150  # 3 out of 4 sessions too slow
        }
      )
    end

    visit prompts_path

    # Should show adaptive prompts
    expect(page).to have_content('recommended').or have_content('adaptive')

    # Should include pace-focused content
    expect(page).to have_content('pace').or have_content('tempo')
  end

  scenario 'User with clarity issues sees clarity-focused adaptive prompts' do
    # Create sessions with clarity problems
    4.times do |i|
      create(:session,
        user: guest_user,
        completed: true,
        created_at: (20 - i).days.ago,
        analysis_data: {
          'clarity_score' => i < 3 ? 0.5 : 0.8  # 3 out of 4 sessions below 0.7 threshold
        }
      )
    end

    visit prompts_path

    # Should show adaptive prompts
    expect(page).to have_content('recommended').or have_content('adaptive')

    # Should include clarity-focused content
    expect(page).to have_content('clarity').or have_content('articulation')
  end

  scenario 'User with confidence issues sees confidence-building prompts' do
    # Create sessions with confidence issues (high filler rate)
    4.times do |i|
      create(:session,
        user: guest_user,
        completed: true,
        created_at: (20 - i).days.ago,
        duration_ms: 60000,
        analysis_data: {
          'filler_rate' => i < 3 ? 0.1 : 0.02  # 3 out of 4 sessions with high filler rate
        }
      )
    end

    visit prompts_path

    # Should show adaptive prompts
    expect(page).to have_content('recommended').or have_content('adaptive')

    # Should include confidence-focused content
    expect(page).to have_content('confidence').or have_content('assertive')
  end

  scenario 'User with multiple issues sees mixed adaptive prompts' do
    # Create sessions with multiple types of issues
    4.times do |i|
      session = create(:session,
        user: guest_user,
        completed: true,
        created_at: (20 - i).days.ago,
        analysis_data: {
          'clarity_score' => 0.6,  # Poor clarity
          'wpm' => 100,           # Too slow
          'filler_rate' => 0.08   # High filler rate
        }
      )

      create(:issue, session: session, category: 'filler_words')
    end

    visit prompts_path

    # Should show adaptive prompts addressing multiple issues
    expect(page).to have_content('recommended').or have_content('adaptive')

    # Might include multiple types of focused prompts
    page_content = page.body.downcase
    issue_types = [ page_content.include?('filler'), page_content.include?('pace'), page_content.include?('clarity') ]
    expect(issue_types.count(true)).to be >= 1
  end

  scenario 'Prompt library shows focus areas for each prompt' do
    visit prompts_path

    # Should display focus areas or descriptions
    expect(page).to have_content('clarity').or have_content('pacing').or have_content('engagement')
  end

  scenario 'Prompt library shows timing information' do
    visit prompts_path

    # Should display target duration information
    expect(page).to have_content('seconds').or have_content('minute')
  end

  scenario 'User can navigate between different prompt categories' do
    visit prompts_path

    # Should be able to access different categories of prompts
    expect(page).to have_content('presentation')
    expect(page).to have_content('conversation')
    expect(page).to have_content('storytelling')

    # All categories should show prompts
    expect(page).to have_content('Elevator Pitch')    # presentation
    expect(page).to have_content('Meeting Introduction') # conversation
  end
end
