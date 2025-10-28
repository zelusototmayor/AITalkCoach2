require 'rails_helper'

RSpec.describe 'Onboarding Flow', type: :system do
  before do
    driven_by(:rack_test) # Use rack_test for faster execution without JavaScript
  end

  describe 'Flow A: User completes demo first, then signs up' do
    let!(:demo_session) { create(:trial_session, :completed) }

    scenario 'User sees demo results reused during onboarding' do
      # Simulate landing page demo completion
      # In reality, this would be done via JavaScript on the landing page
      # For testing, we manually set the cookie
      visit root_path
      page.driver.browser.set_cookie("demo_trial_token=#{demo_session.token}; path=/")

      # User signs up
      visit new_user_registration_path
      fill_in 'Email', with: 'newuser@example.com'
      fill_in 'Password', with: 'password123'
      fill_in 'Password confirmation', with: 'password123'
      click_button 'Sign up'

      # Should redirect to onboarding welcome screen
      expect(current_path).to eq(onboarding_welcome_path)
      expect(page).to have_content('Master the #1 Skill')

      # Screen 1: Welcome - click continue
      click_link 'Start Improving Today'

      # Screen 2: Speaking goals
      expect(current_path).to eq(onboarding_profile_path)
      expect(page).to have_content("What's your main speaking goal?")

      choose 'Better public speaking'
      click_button 'Next'

      # Screen 3: Demographics
      expect(current_path).to eq(onboarding_demographics_path)
      expect(page).to have_content('How would you describe your communication style?')

      choose 'Introvert'
      select '25-34', from: 'Age range'
      fill_in 'Profession', with: 'Software Engineer'
      choose 'They/Them'
      click_button 'Next'

      # Screen 4: Test - should show demo results
      expect(current_path).to eq(onboarding_test_path)
      expect(page).to have_content("Great! You've already tested the app")
      expect(page).to have_content("WPM: #{demo_session.wpm}")
      expect(page).to have_content("Filler Rate: #{demo_session.filler_rate}%")

      click_button 'Continue'

      # Screen 5: Pricing & payment
      expect(current_path).to eq(onboarding_pricing_path)
      expect(page).to have_content('Practice Daily, Use Free Forever')
      expect(page).to have_content('Monthly Plan')
      expect(page).to have_content('Yearly Plan')

      # Simulate Stripe payment method collection
      # In a real test with JavaScript, this would interact with Stripe Elements
      # For now, we'll just test the form submission
      select 'Monthly Plan', from: 'subscription_plan'
      fill_in 'setup_intent_id', with: 'seti_test_123456789'
      click_button 'Add Payment Method & Start Free'

      # Should mark onboarding as complete and redirect to dashboard
      user = User.find_by(email: 'newuser@example.com')
      expect(user.onboarding_completed_at).to be_present
      expect(user.trial_expires_at).to be > Time.current
      expect(user.onboarding_demo_session_id).to eq(demo_session.id)
      expect(current_path).to eq(dashboard_path)
      expect(page).to have_content('Welcome to AI Talk Coach!')
    end

    scenario 'User chooses to try another test despite having demo results' do
      visit root_path
      page.driver.browser.set_cookie("demo_trial_token=#{demo_session.token}; path=/")

      # Sign up and progress through onboarding
      visit new_user_registration_path
      fill_in 'Email', with: 'newuser@example.com'
      fill_in 'Password', with: 'password123'
      fill_in 'Password confirmation', with: 'password123'
      click_button 'Sign up'

      click_link 'Start Improving Today'
      choose 'Better public speaking'
      click_button 'Next'

      choose 'Ambivert'
      select '25-34', from: 'Age range'
      click_button 'Next'

      # Screen 4: Choose to try another test
      expect(page).to have_content("Great! You've already tested the app")
      click_button 'Try Another Test'

      # Should show fresh recording interface
      expect(page).to have_content('30-second practice')
      expect(page).to have_content('Describe your perfect weekend')
      expect(page).to have_button('Record')
    end
  end

  describe 'Flow B: Direct signup (no demo)' do
    scenario 'User completes onboarding with fresh test recording' do
      # User signs up without doing demo first
      visit new_user_registration_path
      fill_in 'Email', with: 'directuser@example.com'
      fill_in 'Password', with: 'password123'
      fill_in 'Password confirmation', with: 'password123'
      click_button 'Sign up'

      # Should redirect to onboarding
      expect(current_path).to eq(onboarding_welcome_path)

      click_link 'Start Improving Today'

      # Screen 2: Speaking goals
      choose 'Job interviews'
      click_button 'Next'

      # Screen 3: Demographics
      choose 'Extrovert'
      select '35-44', from: 'Age range'
      fill_in 'Profession', with: 'Marketing Manager'
      choose 'She/Her'
      click_button 'Next'

      # Screen 4: Test - should offer fresh recording (no demo)
      expect(current_path).to eq(onboarding_test_path)
      expect(page).to have_content("Let's see where you're at")
      expect(page).to have_content('30-second practice')
      expect(page).to have_button('Record')
      expect(page).to have_button('Skip for now')

      # User records a test (simulated)
      # In reality this would involve recording audio and processing
      # For now we'll simulate by clicking record and having the backend create a session
      click_button 'Record'
      # ... recording logic would happen here ...
      # Then submission
      click_button 'Submit Recording'

      # Should proceed to pricing
      expect(current_path).to eq(onboarding_pricing_path)
    end

    scenario 'User skips the test recording' do
      visit new_user_registration_path
      fill_in 'Email', with: 'skipuser@example.com'
      fill_in 'Password', with: 'password123'
      fill_in 'Password confirmation', with: 'password123'
      click_button 'Sign up'

      click_link 'Start Improving Today'

      choose 'Sales & persuasion'
      click_button 'Next'

      choose 'Not sure yet'
      select '45-54', from: 'Age range'
      click_button 'Next'

      # Screen 4: Skip the test
      expect(page).to have_button('Skip for now')
      click_button 'Skip for now'

      # Should proceed to pricing with skipped param
      expect(current_path).to eq(onboarding_pricing_path)
      expect(page.current_url).to include('skipped=true')
    end

    scenario 'User can choose yearly plan during onboarding' do
      visit new_user_registration_path
      fill_in 'Email', with: 'yearlyuser@example.com'
      fill_in 'Password', with: 'password123'
      fill_in 'Password confirmation', with: 'password123'
      click_button 'Sign up'

      # Quick progress through onboarding
      click_link 'Start Improving Today'
      choose 'Better public speaking'
      click_button 'Next'
      choose 'Introvert'
      select '25-34', from: 'Age range'
      click_button 'Next'
      click_button 'Skip for now'

      # Screen 5: Choose yearly plan
      expect(page).to have_content('Yearly Plan')
      expect(page).to have_content('€60/year')
      expect(page).to have_content('Just €5/month • Save 50%')

      select 'Yearly Plan', from: 'subscription_plan'
      fill_in 'setup_intent_id', with: 'seti_test_yearly_123'
      click_button 'Add Payment Method & Start Free'

      user = User.find_by(email: 'yearlyuser@example.com')
      expect(user.subscription_plan).to eq('yearly')
    end
  end

  describe 'Edge cases and validations' do
    scenario 'Expired demo token falls back to fresh test' do
      expired_demo = create(:trial_session, :completed, :expired)

      visit root_path
      page.driver.browser.set_cookie("demo_trial_token=#{expired_demo.token}; path=/")

      visit new_user_registration_path
      fill_in 'Email', with: 'expiredemo@example.com'
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

      # Should NOT show demo results (expired), should show fresh test
      expect(page).not_to have_content("Great! You've already tested the app")
      expect(page).to have_content("Let's see where you're at")
      expect(page).to have_button('Record')
    end

    scenario 'User closing browser mid-onboarding can resume' do
      # User starts onboarding
      visit new_user_registration_path
      fill_in 'Email', with: 'resumeuser@example.com'
      fill_in 'Password', with: 'password123'
      fill_in 'Password confirmation', with: 'password123'
      click_button 'Sign up'

      click_link 'Start Improving Today'
      choose 'Better public speaking'
      click_button 'Next'

      # User closes browser (simulated by logging out and back in)
      click_button 'Sign out'

      # User comes back later
      visit new_user_session_path
      fill_in 'Email', with: 'resumeuser@example.com'
      fill_in 'Password', with: 'password123'
      click_button 'Sign in'

      # Should redirect back to onboarding (not dashboard)
      expect(current_path).to eq(onboarding_welcome_path)

      # User can continue from where they left off
      # Their speaking_goal should be saved
      user = User.find_by(email: 'resumeuser@example.com')
      expect(user.speaking_goal).to eq('Better public speaking')
    end

    scenario 'Payment method collection fails gracefully' do
      visit new_user_registration_path
      fill_in 'Email', with: 'payfail@example.com'
      fill_in 'Password', with: 'password123'
      fill_in 'Password confirmation', with: 'password123'
      click_button 'Sign up'

      # Progress to payment screen
      click_link 'Start Improving Today'
      choose 'Better public speaking'
      click_button 'Next'
      choose 'Introvert'
      select '25-34', from: 'Age range'
      click_button 'Next'
      click_button 'Skip for now'

      # Simulate failed payment (invalid setup intent)
      select 'Monthly Plan', from: 'subscription_plan'
      fill_in 'setup_intent_id', with: 'invalid_intent'
      click_button 'Add Payment Method & Start Free'

      # Should show error and allow retry
      expect(page).to have_content('Payment method could not be added')
      expect(page).to have_button('Add Payment Method & Start Free')
      expect(current_path).to eq(onboarding_pricing_path)
    end
  end

  describe 'Redirects and access control' do
    scenario 'Non-onboarded user cannot access dashboard' do
      user = create(:user)

      # Manually login without onboarding
      visit new_user_session_path
      fill_in 'Email', with: user.email
      fill_in 'Password', with: 'password123'
      click_button 'Sign in'

      # Try to access dashboard
      visit dashboard_path

      # Should redirect to onboarding
      expect(current_path).to eq(onboarding_welcome_path)
      expect(page).to have_content('Please complete onboarding')
    end

    scenario 'Onboarded user can access dashboard normally' do
      user = create(:user, :with_onboarding_completed, :on_free_trial)

      visit new_user_session_path
      fill_in 'Email', with: user.email
      fill_in 'Password', with: 'password123'
      click_button 'Sign in'

      # Should be able to access dashboard
      visit dashboard_path
      expect(current_path).to eq(dashboard_path)
      expect(page).to have_content('Dashboard')
    end
  end
end
