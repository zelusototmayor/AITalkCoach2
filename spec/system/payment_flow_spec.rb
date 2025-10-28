require 'rails_helper'

RSpec.describe 'Payment Flow', type: :system do
  before do
    driven_by(:rack_test)

    # Stub Stripe API calls to avoid hitting real Stripe in tests
    allow(Stripe::SetupIntent).to receive(:create).and_return(
      OpenStruct.new(
        id: 'seti_test_123',
        client_secret: 'seti_test_123_secret_abc'
      )
    )

    allow(Stripe::SetupIntent).to receive(:retrieve).and_return(
      OpenStruct.new(
        id: 'seti_test_123',
        status: 'succeeded',
        payment_method: 'pm_test_card_123'
      )
    )

    allow(Stripe::PaymentMethod).to receive(:attach).and_return(true)
  end

  describe 'Stripe Setup Intent creation' do
    scenario 'Setup intent is created when user reaches pricing screen' do
      visit new_user_registration_path
      fill_in 'Email', with: 'stripe@example.com'
      fill_in 'Password', with: 'password123'
      fill_in 'Password confirmation', with: 'password123'
      click_button 'Sign up'

      # Progress through onboarding to pricing screen
      click_link 'Start Improving Today'
      choose 'Better public speaking'
      click_button 'Next'
      choose 'Introvert'
      select '25-34', from: 'Age range'
      click_button 'Next'
      click_button 'Skip for now'

      # Should have called Stripe to create setup intent
      expect(Stripe::SetupIntent).to have_received(:create).once
      expect(page).to have_content('Monthly Plan')
      expect(page).to have_content('Yearly Plan')
    end
  end

  describe 'Plan selection' do
    before do
      @user = create(:user, email: 'plantest@example.com', password: 'password123')
    end

    scenario 'User selects monthly plan' do
      visit new_user_session_path
      fill_in 'Email', with: 'plantest@example.com'
      fill_in 'Password', with: 'password123'
      click_button 'Sign in'

      # Progress to pricing
      click_link 'Start Improving Today'
      choose 'Better public speaking'
      click_button 'Next'
      choose 'Ambivert'
      select '25-34', from: 'Age range'
      click_button 'Next'
      click_button 'Skip for now'

      # Select monthly plan
      choose 'Monthly Plan'
      fill_in 'setup_intent_id', with: 'seti_test_monthly'
      click_button 'Add Payment Method & Start Free'

      # Verify plan saved
      @user.reload
      expect(@user.subscription_plan).to eq('monthly')
      expect(@user.onboarding_completed_at).to be_present
    end

    scenario 'User selects yearly plan' do
      visit new_user_session_path
      fill_in 'Email', with: 'plantest@example.com'
      fill_in 'Password', with: 'password123'
      click_button 'Sign in'

      # Progress to pricing
      click_link 'Start Improving Today'
      choose 'Better public speaking'
      click_button 'Next'
      choose 'Ambivert'
      select '25-34', from: 'Age range'
      click_button 'Next'
      click_button 'Skip for now'

      # Select yearly plan
      choose 'Yearly Plan'
      fill_in 'setup_intent_id', with: 'seti_test_yearly'
      click_button 'Add Payment Method & Start Free'

      # Verify plan saved
      @user.reload
      expect(@user.subscription_plan).to eq('yearly')
      expect(@user.onboarding_completed_at).to be_present
    end

    scenario 'Yearly plan shows savings badge' do
      visit new_user_session_path
      fill_in 'Email', with: 'plantest@example.com'
      fill_in 'Password', with: 'password123'
      click_button 'Sign in'

      # Progress to pricing
      click_link 'Start Improving Today'
      choose 'Better public speaking'
      click_button 'Next'
      choose 'Ambivert'
      select '25-34', from: 'Age range'
      click_button 'Next'
      click_button 'Skip for now'

      # Verify savings messaging
      expect(page).to have_content('BEST VALUE')
      expect(page).to have_content('Save 50%')
      expect(page).to have_content('Just €5/month')
    end
  end

  describe 'Payment method validation' do
    before do
      @user = create(:user, email: 'validation@example.com', password: 'password123')
    end

    scenario 'Valid payment method is saved successfully' do
      visit new_user_session_path
      fill_in 'Email', with: 'validation@example.com'
      fill_in 'Password', with: 'password123'
      click_button 'Sign in'

      # Progress to pricing
      click_link 'Start Improving Today'
      choose 'Better public speaking'
      click_button 'Next'
      choose 'Ambivert'
      select '25-34', from: 'Age range'
      click_button 'Next'
      click_button 'Skip for now'

      # Submit valid payment
      choose 'Monthly Plan'
      fill_in 'setup_intent_id', with: 'seti_test_valid'
      click_button 'Add Payment Method & Start Free'

      # Verify payment method saved
      @user.reload
      expect(@user.stripe_payment_method_id).to eq('pm_test_card_123')
      expect(@user.subscription_status).to eq('free_trial')
      expect(@user.trial_expires_at).to be > Time.current
    end

    scenario 'Failed payment shows error message' do
      # Stub failed setup intent
      allow(Stripe::SetupIntent).to receive(:retrieve).and_return(
        OpenStruct.new(
          id: 'seti_test_failed',
          status: 'failed',
          last_setup_error: OpenStruct.new(message: 'Your card was declined')
        )
      )

      visit new_user_session_path
      fill_in 'Email', with: 'validation@example.com'
      fill_in 'Password', with: 'password123'
      click_button 'Sign in'

      # Progress to pricing
      click_link 'Start Improving Today'
      choose 'Better public speaking'
      click_button 'Next'
      choose 'Ambivert'
      select '25-34', from: 'Age range'
      click_button 'Next'
      click_button 'Skip for now'

      # Submit failed payment
      choose 'Monthly Plan'
      fill_in 'setup_intent_id', with: 'seti_test_failed'
      click_button 'Add Payment Method & Start Free'

      # Should show error and stay on page
      expect(page).to have_content('Your card was declined')
      expect(current_path).to eq(onboarding_pricing_path)

      # Payment method should NOT be saved
      @user.reload
      expect(@user.stripe_payment_method_id).to be_nil
    end

    scenario 'Card validation errors are displayed' do
      # Stub validation error
      allow(Stripe::SetupIntent).to receive(:retrieve).and_return(
        OpenStruct.new(
          id: 'seti_test_invalid',
          status: 'requires_payment_method',
          last_setup_error: OpenStruct.new(message: "Your card's security code is incorrect")
        )
      )

      visit new_user_session_path
      fill_in 'Email', with: 'validation@example.com'
      fill_in 'Password', with: 'password123'
      click_button 'Sign in'

      # Progress to pricing
      click_link 'Start Improving Today'
      choose 'Better public speaking'
      click_button 'Next'
      choose 'Ambivert'
      select '25-34', from: 'Age range'
      click_button 'Next'
      click_button 'Skip for now'

      # Submit invalid card
      choose 'Monthly Plan'
      fill_in 'setup_intent_id', with: 'seti_test_invalid'
      click_button 'Add Payment Method & Start Free'

      # Should show specific validation error
      expect(page).to have_content("Your card's security code is incorrect")
      expect(page).to have_button('Add Payment Method & Start Free') # Allow retry
    end
  end

  describe 'Trial activation' do
    before do
      @user = create(:user, email: 'trial@example.com', password: 'password123')
    end

    scenario 'Trial is activated after payment method added' do
      visit new_user_session_path
      fill_in 'Email', with: 'trial@example.com'
      fill_in 'Password', with: 'password123'
      click_button 'Sign in'

      # Progress through onboarding
      click_link 'Start Improving Today'
      choose 'Better public speaking'
      click_button 'Next'
      choose 'Ambivert'
      select '25-34', from: 'Age range'
      click_button 'Next'
      click_button 'Skip for now'

      # Add payment method
      choose 'Monthly Plan'
      fill_in 'setup_intent_id', with: 'seti_test_trial'
      click_button 'Add Payment Method & Start Free'

      # Verify trial activated
      @user.reload
      expect(@user.trial_starts_at).to be_present
      expect(@user.trial_expires_at).to be_present
      expect(@user.trial_expires_at).to be > Time.current
      expect(@user.trial_expires_at).to be < 25.hours.from_now
      expect(@user.subscription_status).to eq('free_trial')
    end

    scenario 'User redirected to dashboard after trial activation' do
      visit new_user_session_path
      fill_in 'Email', with: 'trial@example.com'
      fill_in 'Password', with: 'password123'
      click_button 'Sign in'

      # Complete onboarding
      click_link 'Start Improving Today'
      choose 'Better public speaking'
      click_button 'Next'
      choose 'Ambivert'
      select '25-34', from: 'Age range'
      click_button 'Next'
      click_button 'Skip for now'
      choose 'Monthly Plan'
      fill_in 'setup_intent_id', with: 'seti_test_redirect'
      click_button 'Add Payment Method & Start Free'

      # Should redirect to dashboard
      expect(current_path).to eq(dashboard_path)
      expect(page).to have_content('Welcome to AI Talk Coach!')
      expect(page).to have_content('Your free trial is active')
    end
  end

  describe 'Stripe customer creation' do
    scenario 'Stripe customer is created if not exists' do
      allow(Stripe::Customer).to receive(:create).and_return(
        OpenStruct.new(id: 'cus_new_customer_123')
      )

      visit new_user_registration_path
      fill_in 'Email', with: 'newcustomer@example.com'
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
      click_button 'Skip for now'
      choose 'Monthly Plan'
      fill_in 'setup_intent_id', with: 'seti_test_new_customer'
      click_button 'Add Payment Method & Start Free'

      # Verify customer was created
      user = User.find_by(email: 'newcustomer@example.com')
      expect(user.stripe_customer_id).to eq('cus_new_customer_123')
    end

    scenario 'Existing Stripe customer is reused' do
      user = create(:user, email: 'existing@example.com', password: 'password123',
                    stripe_customer_id: 'cus_existing_123')

      visit new_user_session_path
      fill_in 'Email', with: 'existing@example.com'
      fill_in 'Password', with: 'password123'
      click_button 'Sign in'

      # Progress through onboarding
      click_link 'Start Improving Today'
      choose 'Better public speaking'
      click_button 'Next'
      choose 'Ambivert'
      select '25-34', from: 'Age range'
      click_button 'Next'
      click_button 'Skip for now'
      choose 'Monthly Plan'
      fill_in 'setup_intent_id', with: 'seti_test_existing'
      click_button 'Add Payment Method & Start Free'

      # Customer ID should not change
      user.reload
      expect(user.stripe_customer_id).to eq('cus_existing_123')
    end
  end

  describe 'No charging during onboarding' do
    scenario 'Payment method is saved but user is NOT charged yet' do
      # Ensure PaymentIntent.create is NOT called
      allow(Stripe::PaymentIntent).to receive(:create).and_call_original

      visit new_user_registration_path
      fill_in 'Email', with: 'nocharge@example.com'
      fill_in 'Password', with: 'password123'
      fill_in 'Password confirmation', with: 'password123'
      click_button 'Sign up'

      # Complete onboarding
      click_link 'Start Improving Today'
      choose 'Better public speaking'
      click_button 'Next'
      choose 'Ambivert'
      select '25-34', from: 'Age range'
      click_button 'Next'
      click_button 'Skip for now'
      choose 'Monthly Plan'
      fill_in 'setup_intent_id', with: 'seti_test_no_charge'
      click_button 'Add Payment Method & Start Free'

      # Verify NO payment intent was created (only setup intent)
      expect(Stripe::PaymentIntent).not_to have_received(:create)

      # User should be on free trial
      user = User.find_by(email: 'nocharge@example.com')
      expect(user.subscription_status).to eq('free_trial')
      expect(user.stripe_payment_method_id).to be_present
    end
  end

  describe 'Cancel anytime messaging' do
    scenario 'Cancel anytime message is displayed' do
      visit new_user_registration_path
      fill_in 'Email', with: 'cancel@example.com'
      fill_in 'Password', with: 'password123'
      fill_in 'Password confirmation', with: 'password123'
      click_button 'Sign up'

      # Progress to pricing
      click_link 'Start Improving Today'
      choose 'Better public speaking'
      click_button 'Next'
      choose 'Ambivert'
      select '25-34', from: 'Age range'
      click_button 'Next'
      click_button 'Skip for now'

      # Verify messaging
      expect(page).to have_content('Cancel anytime')
      expect(page).to have_content("You'll only start being charged after you miss a day of practice")
    end
  end
end
