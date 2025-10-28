require 'rails_helper'

RSpec.describe 'Demo Reuse Flow', type: :system do
  before do
    driven_by(:rack_test)
  end

  describe 'Cookie-based demo linking' do
    let!(:demo_session) { create(:trial_session, :completed, created_at: 30.minutes.ago) }

    scenario 'Demo token is stored and retrieved correctly' do
      # Simulate landing page setting cookie after demo completion
      visit root_path
      page.driver.browser.set_cookie("demo_trial_token=#{demo_session.token}; path=/; max-age=3600")

      # Sign up
      visit new_user_registration_path
      fill_in 'Email', with: 'cookietest@example.com'
      fill_in 'Password', with: 'password123'
      fill_in 'Password confirmation', with: 'password123'
      click_button 'Sign up'

      # Progress through onboarding
      click_link 'Start Improving Today'
      choose 'Better public speaking'
      click_button 'Next'
      choose 'Introvert'
      select '25-34', from: 'Age range'
      click_button 'Next'

      # On test screen, should see demo results
      expect(page).to have_content("Great! You've already tested the app")

      # Verify demo session is linked to user
      user = User.find_by(email: 'cookietest@example.com')
      expect(user.onboarding_demo_session_id).to eq(demo_session.id)
    end

    scenario 'Demo linking works within 1 hour window' do
      # Create demo from exactly 59 minutes ago (still valid)
      recent_demo = create(:trial_session, :completed, created_at: 59.minutes.ago)

      visit root_path
      page.driver.browser.set_cookie("demo_trial_token=#{recent_demo.token}; path=/")

      visit new_user_registration_path
      fill_in 'Email', with: 'recent@example.com'
      fill_in 'Password', with: 'password123'
      fill_in 'Password confirmation', with: 'password123'
      click_button 'Sign up'

      # Progress to test screen
      click_link 'Start Improving Today'
      choose 'Better public speaking'
      click_button 'Next'
      choose 'Ambivert'
      select '25-34', from: 'Age range'
      click_button 'Next'

      # Should still show demo results (within 1 hour)
      expect(page).to have_content("Great! You've already tested the app")
    end

    scenario 'Expired demo token (over 1 hour) is not reused' do
      # Create demo from 61 minutes ago (expired)
      old_demo = create(:trial_session, :completed, created_at: 61.minutes.ago)

      visit root_path
      page.driver.browser.set_cookie("demo_trial_token=#{old_demo.token}; path=/")

      visit new_user_registration_path
      fill_in 'Email', with: 'expired@example.com'
      fill_in 'Password', with: 'password123'
      fill_in 'Password confirmation', with: 'password123'
      click_button 'Sign up'

      # Progress to test screen
      click_link 'Start Improving Today'
      choose 'Better public speaking'
      click_button 'Next'
      choose 'Introvert'
      select '25-34', from: 'Age range'
      click_button 'Next'

      # Should NOT show demo results, should offer fresh test
      expect(page).not_to have_content("Great! You've already tested the app")
      expect(page).to have_content("Let's see where you're at")
      expect(page).to have_button('Record')
    end

    scenario 'Invalid demo token does not break flow' do
      # Set cookie with non-existent token
      visit root_path
      page.driver.browser.set_cookie("demo_trial_token=invalid_token_12345; path=/")

      visit new_user_registration_path
      fill_in 'Email', with: 'invalid@example.com'
      fill_in 'Password', with: 'password123'
      fill_in 'Password confirmation', with: 'password123'
      click_button 'Sign up'

      # Progress to test screen
      click_link 'Start Improving Today'
      choose 'Better public speaking'
      click_button 'Next'
      choose 'Ambivert'
      select '25-34', from: 'Age range'
      click_button 'Next'

      # Should gracefully fall back to fresh test
      expect(page).to have_content("Let's see where you're at")
      expect(page).to have_button('Record')

      # Should not error out
      expect(page).not_to have_content('error')
      expect(page).not_to have_content('500')
    end

    scenario 'No cookie present defaults to fresh test' do
      # No cookie set
      visit new_user_registration_path
      fill_in 'Email', with: 'nocookie@example.com'
      fill_in 'Password', with: 'password123'
      fill_in 'Password confirmation', with: 'password123'
      click_button 'Sign up'

      # Progress to test screen
      click_link 'Start Improving Today'
      choose 'Better public speaking'
      click_button 'Next'
      choose 'Ambivert'
      select '25-34', from: 'Age range'
      click_button 'Next'

      # Should show fresh test interface
      expect(page).to have_content("Let's see where you're at")
      expect(page).to have_button('Record')
    end
  end

  describe 'Multiple demos handling' do
    scenario 'Most recent demo is used when multiple exist' do
      # Create multiple demos
      old_demo = create(:trial_session, :completed, created_at: 50.minutes.ago,
                       analysis_data: { 'wpm' => 100, 'filler_count' => 5 })
      new_demo = create(:trial_session, :completed, created_at: 10.minutes.ago,
                       analysis_data: { 'wpm' => 150, 'filler_count' => 2 })

      # Cookie has the newest demo token
      visit root_path
      page.driver.browser.set_cookie("demo_trial_token=#{new_demo.token}; path=/")

      visit new_user_registration_path
      fill_in 'Email', with: 'multiple@example.com'
      fill_in 'Password', with: 'password123'
      fill_in 'Password confirmation', with: 'password123'
      click_button 'Sign up'

      # Progress to test screen
      click_link 'Start Improving Today'
      choose 'Better public speaking'
      click_button 'Next'
      choose 'Ambivert'
      select '25-34', from: 'Age range'
      click_button 'Next'

      # Should show the most recent demo results
      expect(page).to have_content('WPM: 150')
      expect(page).not_to have_content('WPM: 100')
    end
  end

  describe 'Demo session must be completed' do
    scenario 'Pending demo is not reused' do
      pending_demo = create(:trial_session, processing_state: 'pending', created_at: 10.minutes.ago)

      visit root_path
      page.driver.browser.set_cookie("demo_trial_token=#{pending_demo.token}; path=/")

      visit new_user_registration_path
      fill_in 'Email', with: 'pending@example.com'
      fill_in 'Password', with: 'password123'
      fill_in 'Password confirmation', with: 'password123'
      click_button 'Sign up'

      # Progress to test screen
      click_link 'Start Improving Today'
      choose 'Better public speaking'
      click_button 'Next'
      choose 'Ambivert'
      select '25-34', from: 'Age range'
      click_button 'Next'

      # Should NOT show demo results (not completed), should offer fresh test
      expect(page).not_to have_content("Great! You've already tested the app")
      expect(page).to have_content("Let's see where you're at")
    end

    scenario 'Failed demo is not reused' do
      failed_demo = create(:trial_session, :failed, created_at: 10.minutes.ago)

      visit root_path
      page.driver.browser.set_cookie("demo_trial_token=#{failed_demo.token}; path=/")

      visit new_user_registration_path
      fill_in 'Email', with: 'failed@example.com'
      fill_in 'Password', with: 'password123'
      fill_in 'Password confirmation', with: 'password123'
      click_button 'Sign up'

      # Progress to test screen
      click_link 'Start Improving Today'
      choose 'Better public speaking'
      click_button 'Next'
      choose 'Ambivert'
      select '25-34', from: 'Age range'
      click_button 'Next'

      # Should NOT show demo results (failed), should offer fresh test
      expect(page).not_to have_content("Great! You've already tested the app")
      expect(page).to have_content("Let's see where you're at")
    end

    scenario 'Only completed demos are linked to user account' do
      completed_demo = create(:trial_session, :completed, created_at: 10.minutes.ago)

      visit root_path
      page.driver.browser.set_cookie("demo_trial_token=#{completed_demo.token}; path=/")

      visit new_user_registration_path
      fill_in 'Email', with: 'completed@example.com'
      fill_in 'Password', with: 'password123'
      fill_in 'Password confirmation', with: 'password123'
      click_button 'Sign up'

      # Progress through onboarding
      click_link 'Start Improving Today'
      choose 'Better public speaking'
      click_button 'Next'
      choose 'Ambivert'
      select '25-34', from: 'Age range'
      click_button 'Next'

      # Verify completed demo is linked
      user = User.find_by(email: 'completed@example.com')
      expect(user.onboarding_demo_session_id).to eq(completed_demo.id)

      # Verify it's a completed demo
      linked_demo = TrialSession.find(user.onboarding_demo_session_id)
      expect(linked_demo.processing_state).to eq('completed')
    end
  end

  describe 'Demo data display' do
    scenario 'Demo results are accurately displayed' do
      demo = create(:trial_session, :with_analysis_data, created_at: 10.minutes.ago)

      visit root_path
      page.driver.browser.set_cookie("demo_trial_token=#{demo.token}; path=/")

      visit new_user_registration_path
      fill_in 'Email', with: 'display@example.com'
      fill_in 'Password', with: 'password123'
      fill_in 'Password confirmation', with: 'password123'
      click_button 'Sign up'

      # Progress to test screen
      click_link 'Start Improving Today'
      choose 'Better public speaking'
      click_button 'Next'
      choose 'Ambivert'
      select '25-34', from: 'Age range'
      click_button 'Next'

      # Verify all key metrics are displayed
      analysis = demo.analysis_data
      expect(page).to have_content("WPM: #{analysis['wpm']}")
      expect(page).to have_content("Filler Rate: #{demo.filler_rate}%")
      expect(page).to have_content("Clarity Score: #{demo.clarity_score}")
    end
  end
end
