# Onboarding Implementation Plan

## Overview
This document outlines the complete implementation plan for the user onboarding flow, including profile collection, demo session reuse, and payment setup.

---

## 📋 Phase 1: Database Schema & Models

### 1.1 Create Migration for User Onboarding Fields

```ruby
# db/migrate/YYYYMMDDHHMMSS_add_onboarding_to_users.rb
add_column :users, :speaking_goal, :string
add_column :users, :speaking_style, :string
add_column :users, :age_range, :string
add_column :users, :profession, :string
add_column :users, :preferred_pronouns, :string
add_column :users, :onboarding_completed_at, :datetime
add_column :users, :onboarding_demo_session_id, :integer # Links to TrialSession if coming from demo
```

### 1.2 Update User Model

```ruby
# app/models/user.rb
def onboarding_completed?
  onboarding_completed_at.present?
end

def needs_onboarding?
  !onboarding_completed?
end

def link_demo_session(trial_session)
  update(onboarding_demo_session_id: trial_session.id)
end
```

Add validations for onboarding fields (optional, since they're collected during onboarding).

---

## 📋 Phase 2: Onboarding Controller & Routes

### 2.1 Create OnboardingController

```ruby
# app/controllers/onboarding_controller.rb
class OnboardingController < ApplicationController
  before_action :authenticate_user!

  # Actions: welcome, profile, demographics, test, pricing, complete
  # Each screen is a separate action with GET/POST for form submission
end
```

### 2.2 Update Routes

```ruby
# config/routes.rb
namespace :onboarding do
  get :welcome      # Screen 1: Why communication matters
  get :profile      # Screen 2: Speaking goals
  post :profile
  get :demographics # Screen 3: Style + demographics + pronouns
  post :demographics
  get :test         # Screen 4: 30-second test (or show existing demo results)
  post :test
  get :pricing      # Screen 5: Payment collection
  post :pricing
  post :complete    # Finalize onboarding
end
```

### 2.3 Add Redirect Logic After Signup

In `Auth::RegistrationsController#create`, after successful signup → redirect to `onboarding_welcome_path`.

Add `before_action :require_onboarding` to ApplicationController (skip for onboarding/auth/public routes).

---

## 📋 Phase 3: Screen 1 - Why Communication Matters

### 3.1 View: `app/views/onboarding/welcome.html.erb`

**Content:**
- Hero headline: "Master the #1 Skill That Opens Every Door"
- Subheadline: LinkedIn stat
- Three stat cards with icons:
  - 85% career success from communication
  - 40% higher earnings for strong communicators
  - 1.9M job postings requiring communication
- CTA button: "Start Improving Today" → `onboarding_profile_path`
- No form, just informational page

---

## 📋 Phase 4: Screen 2 - Speaking Goals

### 4.1 View: `app/views/onboarding/profile.html.erb`

**Question:** "What's your main speaking goal?"

**Options (radio buttons or card selection):**
- Better public speaking
- Nail presentations at work
- Improve social conversations
- Podcasting/content creation
- Sales & persuasion
- Job interviews
- Other (text input)

**UI Elements:**
- Progress indicator: "Step 1 of 4"
- Button: "Next" → POST to `onboarding_profile_path` → redirects to `onboarding_demographics_path`

### 4.2 Controller Logic

```ruby
def profile
  # GET: render form
end

def create_profile
  if current_user.update(speaking_goal: params[:speaking_goal])
    redirect_to onboarding_demographics_path
  else
    render :profile
  end
end
```

---

## 📋 Phase 5: Screen 3 - Style + Demographics + Pronouns

### 5.1 View: `app/views/onboarding/demographics.html.erb`

**Section A: Speaking Style**
- Question: "How would you describe your communication style?"
- Radio options: Introvert, Extrovert, Ambivert, Not sure yet

**Section B: Demographics**
- Age range dropdown: 18-24, 25-34, 35-44, 45-54, 55+
- Profession: Free text input (optional)

**Section C: Pronouns (Optional)**
- Label: "How should we refer to you? (Optional - helps personalize coaching)"
- Radio options: He/Him, She/Her, They/Them, Prefer not to say, Other (custom input)
- Visually indicate this is skippable

**UI Elements:**
- Progress indicator: "Step 2 of 4"
- Button: "Next" → POST to `onboarding_demographics_path` → redirects to `onboarding_test_path`

### 5.2 Controller Logic

Save `speaking_style`, `age_range`, `profession`, `preferred_pronouns` to `current_user`.
Validate required fields only (pronouns optional).
Redirect to test step.

---

## 📋 Phase 6: Screen 4 - 30-Second Test (with Demo Reuse)

### 6.1 Demo Linking Strategy (Cookie-Based)

**When user does landing page demo:**

```javascript
// After TrialSession is created on landing page
// Store token in cookie (persists across redirects)
document.cookie = `demo_trial_token=${trial_token}; max-age=3600; path=/`;
```

**During onboarding Screen 4 GET request:**

```ruby
# In OnboardingController#test
demo_token = cookies[:demo_trial_token]
if demo_token
  @trial_session = TrialSession.find_by(token: demo_token, created_at: 1.hour.ago..)
  if @trial_session && @trial_session.completed?
    # Link to user account
    current_user.update(onboarding_demo_session_id: @trial_session.id)
    @demo_completed = true
  end
end
```

### 6.2 View: Two States

**State A - Demo Already Completed:**
- Header: "Great! You've already tested the app"
- Show demo results (WPM, filler rate, clarity score)
- Two buttons:
  - Primary: "Continue" → `onboarding_pricing_path`
  - Secondary: "Try Another Test" → Show fresh recording interface

**State B - No Demo / Fresh Test:**
- Header: "Let's see where you're at - try a 30-second practice!"
- Prompt visible: "Describe your perfect weekend"
- Record button (reuse existing recording component)
- Skip button: "Skip for now" → `onboarding_pricing_path?skipped=true`

### 6.3 Controller Logic

- GET: Check for existing demo, render appropriate state
- POST: Handle fresh test recording → create Session → redirect to pricing

---

## 📋 Phase 7: Screen 5 - Pricing & Payment Collection

### 7.1 View: `app/views/onboarding/pricing.html.erb`

```html
<div class="pricing-onboarding-card">
  <h2>🎯 Practice Daily, Use Free Forever</h2>

  <div class="pricing-cards">
    <div class="plan-card" data-plan="monthly">
      <h3>Monthly Plan</h3>
      <div class="price">€9.99<span>/month</span></div>
    </div>

    <div class="plan-card recommended" data-plan="yearly">
      <div class="badge">BEST VALUE</div>
      <h3>Yearly Plan</h3>
      <div class="price">€60<span>/year</span></div>
      <p class="savings">Just €5/month • Save 50%</p>
    </div>
  </div>

  <p class="charge-notice">
    💳 You'll only start being charged after you miss a day of practice
  </p>

  <div id="stripe-card-element"></div>

  <button id="submit-payment" class="primary-btn">
    Add Payment Method & Start Free
  </button>

  <p class="small-text">Cancel anytime</p>
</div>
```

### 7.2 Stripe Integration

**Controller (GET):**

```ruby
# In OnboardingController#pricing
@setup_intent = Stripe::SetupIntent.create(
  customer: current_user.stripe_customer_id,
  payment_method_types: ['card']
)
```

**View (JavaScript):**

```javascript
const stripe = Stripe('<%= Rails.application.credentials.dig(:stripe, :publishable_key) %>');
const elements = stripe.elements();
const cardElement = elements.create('card');
cardElement.mount('#stripe-card-element');

// On submit
const { setupIntent, error } = await stripe.confirmCardSetup(
  '<%= @setup_intent.client_secret %>',
  {
    payment_method: { card: cardElement }
  }
);

// POST to onboarding_pricing_path with setupIntent.id
```

### 7.3 Controller Logic (POST)

- Receive `setup_intent_id` and `selected_plan` (monthly/yearly)
- Verify SetupIntent with Stripe API
- Save payment method to Stripe Customer
- Update user: `subscription_plan = selected_plan`, but DON'T charge yet
- Set user's initial trial start
- Redirect to `onboarding_complete_path`

---

## 📋 Phase 8: Onboarding Complete & Trial Activation

### 8.1 Controller Action: `complete`

```ruby
def complete
  current_user.update!(
    onboarding_completed_at: Time.current,
    trial_starts_at: Time.current,
    trial_expires_at: 24.hours.from_now
  )

  redirect_to dashboard_path, notice: "Welcome to AI Talk Coach! Your free trial is active."
end
```

### 8.2 Add Middleware to Block Non-Onboarded Users

```ruby
# In ApplicationController
before_action :require_onboarding, unless: :skip_onboarding_check?

private

def require_onboarding
  if logged_in? && current_user.onboarding_completed_at.nil?
    redirect_to onboarding_welcome_path unless request.path.starts_with?('/onboarding')
  end
end

def skip_onboarding_check?
  devise_controller? ||
  controller_name == 'landing' ||
  controller_name == 'pricing' ||
  controller_path.starts_with?('onboarding/')
end
```

---

## 📋 Phase 9: Billing Logic Updates

### 9.1 Daily Cron Job

```ruby
# In lib/tasks/daily_billing.rake or similar
User.where("trial_expires_at < ?", Time.current)
    .where("subscription_status != 'active'")
    .find_each do |user|

  # User missed their practice day - charge them
  Billing::ChargeUser.call(user)

  # After successful charge, mark as regular subscriber
  user.update!(
    subscription_status: 'active',
    subscription_started_at: Time.current,
    next_billing_date: calculate_next_billing(user.subscription_plan)
  )
end
```

### 9.2 Billing Service

```ruby
# app/services/billing/charge_user.rb
class Billing::ChargeUser
  def self.call(user)
    amount = user.subscription_plan == 'yearly' ? 6000 : 999 # cents

    Stripe::PaymentIntent.create(
      amount: amount,
      currency: 'eur',
      customer: user.stripe_customer_id,
      payment_method: user.stripe_payment_method_id,
      off_session: true,
      confirm: true
    )

    # Send receipt email
    UserMailer.subscription_charged(user).deliver_later
  rescue Stripe::CardError => e
    # Retry 3 times, then block access
    handle_failed_payment(user, e)
  end
end
```

---

## 📋 Phase 10: UI/UX Polish

### 10.1 Progress Indicator Component

```erb
<!-- app/views/onboarding/_progress.html.erb -->
<div class="onboarding-progress">
  <div class="step <%= 'active' if current_step >= 1 %>">1</div>
  <div class="connector <%= 'active' if current_step >= 2 %>"></div>
  <div class="step <%= 'active' if current_step >= 2 %>">2</div>
  <div class="connector <%= 'active' if current_step >= 3 %>"></div>
  <div class="step <%= 'active' if current_step >= 3 %>">3</div>
  <div class="connector <%= 'active' if current_step >= 4 %>"></div>
  <div class="step <%= 'active' if current_step >= 4 %>">4</div>
</div>
```

### 10.2 Mobile Responsiveness

- Stack pricing cards vertically on mobile
- Ensure Stripe card element is mobile-friendly
- Test recording interface on mobile

### 10.3 Accessibility

- Proper label associations
- Keyboard navigation
- Screen reader support for progress indicator

---

## 📁 Files to Create/Modify

### New Files (15)

1. `db/migrate/YYYYMMDDHHMMSS_add_onboarding_to_users.rb`
2. `app/controllers/onboarding_controller.rb`
3. `app/views/onboarding/welcome.html.erb`
4. `app/views/onboarding/profile.html.erb`
5. `app/views/onboarding/demographics.html.erb`
6. `app/views/onboarding/test.html.erb`
7. `app/views/onboarding/pricing.html.erb`
8. `app/views/onboarding/_progress.html.erb`
9. `app/javascript/controllers/onboarding_payment_controller.js` (Stimulus)
10. `app/javascript/controllers/onboarding_demo_controller.js` (Stimulus)
11. `app/services/billing/charge_user.rb`
12. `app/services/onboarding/link_demo_session.rb`
13. `app/mailers/onboarding_mailer.rb`
14. `app/views/onboarding_mailer/welcome.html.erb`
15. `spec/system/onboarding_flow_spec.rb`

### Modified Files (8)

1. `config/routes.rb` - Add onboarding namespace
2. `app/controllers/application_controller.rb` - Add onboarding redirect middleware
3. `app/controllers/auth/registrations_controller.rb` - Redirect to onboarding after signup
4. `app/models/user.rb` - Add onboarding helper methods
5. `app/controllers/landing_controller.rb` - Store demo token in cookie
6. `app/views/landing/index.html.erb` - Update demo CTA to store token
7. `lib/tasks/daily_billing.rake` - Update to handle first charge
8. `app/assets/stylesheets/main.css` - Add onboarding styles

---

## 🧪 Testing Checklist

### Flow A: User Does Demo First

- [ ] User completes demo on landing page
- [ ] Demo token stored in cookie
- [ ] User signs up
- [ ] Redirected to onboarding welcome
- [ ] Progresses through profile + demographics
- [ ] Test screen shows "You already completed a test" with results
- [ ] User continues to pricing
- [ ] Adds payment method successfully
- [ ] Redirected to dashboard with 24hr trial

### Flow B: Direct Signup

- [ ] User signs up directly
- [ ] Redirected to onboarding welcome
- [ ] Progresses through profile + demographics
- [ ] Test screen offers fresh recording
- [ ] User completes or skips test
- [ ] Adds payment method successfully
- [ ] Redirected to dashboard with 24hr trial

### Billing Logic

- [ ] User completes 1+ min session → trial extended by 24 hours
- [ ] User misses a day → charged at midnight
- [ ] After charge, `subscription_status = 'active'`
- [ ] No more trial extensions (regular subscriber now)
- [ ] Card decline → 3 retries → block access + notification

### Edge Cases

- [ ] User closes browser mid-onboarding → Can resume where left off
- [ ] Demo token expires (1 hour) → Offer fresh test
- [ ] Payment fails → Show error, allow retry
- [ ] User already has subscription → Skip onboarding (shouldn't happen for new users)

---

## 📊 Success Metrics

After implementation, track:

- **Onboarding completion rate:** % of signups who complete all 5 screens
- **Drop-off points:** Which screen has highest abandonment
- **Demo reuse rate:** % of users who complete landing demo before signup
- **Payment collection success:** % who successfully add payment method
- **Time to complete:** Median time from signup to dashboard

---

## ⏱️ Estimated Implementation Time

- **Phase 1-2** (DB + Controllers): 2 hours
- **Phase 3-5** (Screens 1-3): 3 hours
- **Phase 6** (Demo reuse logic): 2 hours
- **Phase 7** (Stripe payment): 3 hours
- **Phase 8-9** (Completion + billing): 2 hours
- **Phase 10** (Polish + testing): 2 hours

**Total:** ~14-16 hours of focused development

---

## 🚀 Getting Started

1. Review this document with the team
2. Create a project board with tickets for each phase
3. Assign phases to developers
4. Start with Phase 1 (database) and Phase 2 (routes/controllers)
5. Implement screens in parallel once foundation is ready
6. Test thoroughly using the checklist above
