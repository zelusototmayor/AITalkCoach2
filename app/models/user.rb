class User < ApplicationRecord
  has_secure_password

  has_many :sessions, dependent: :destroy
  has_many :weekly_focuses, dependent: :destroy, class_name: "WeeklyFocus"
  has_many :user_issue_embeddings, dependent: :destroy
  has_many :issues, through: :sessions
  has_many :prompt_completions, dependent: :destroy

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true, length: { minimum: 2, maximum: 50 }
  validates :password, length: { minimum: 6 }, if: -> { new_record? || !password.nil? }
  validates :preferred_language, inclusion: { in: -> (_) { LanguageService.supported_language_codes } }, allow_blank: false
  validates :target_wpm, numericality: { only_integer: true, greater_than_or_equal_to: 60, less_than_or_equal_to: 240 }, allow_nil: true

  # Serialize speaking_goal as JSON array
  serialize :speaking_goal, coder: JSON

  # Subscription status enum - declare attribute type for Rails 8
  attribute :subscription_status, :string, default: "free_trial"
  enum :subscription_status, {
    free_trial: "free_trial",
    active: "active",
    canceled: "canceled",
    past_due: "past_due",
    lifetime: "lifetime"
  }, prefix: :subscription


  # Password reset methods
  def generate_reset_password_token!
    self.reset_password_token = SecureRandom.urlsafe_base64
    self.reset_password_sent_at = Time.current
    save!(validate: false)
  end

  def reset_password_token_expired?
    return true if reset_password_sent_at.nil?
    reset_password_sent_at < 24.hours.ago
  end

  def reset_password!(new_password)
    self.password = new_password
    self.reset_password_token = nil
    self.reset_password_sent_at = nil
    save!
  end

  def self.find_by_valid_reset_token(token)
    user = find_by(reset_password_token: token)
    return nil if user.nil? || user.reset_password_token_expired?
    user
  end

  # ============================================================================
  # ONBOARDING METHODS
  # ============================================================================

  # Check if user has completed onboarding
  def onboarding_completed?
    onboarding_completed_at.present?
  end

  # Check if user needs to complete onboarding
  # Lifetime users are grandfathered and don't need onboarding
  def needs_onboarding?
    return false if subscription_lifetime?
    !onboarding_completed?
  end

  # Link a demo trial session to the user account
  def link_demo_session(trial_session)
    update(onboarding_demo_session_id: trial_session.id)
  end

  # ============================================================================
  # LANGUAGE PREFERENCE METHODS
  # ============================================================================

  # Get the language to use for sessions
  # Returns user's preferred language or default
  def language_for_sessions
    preferred_language.presence || LanguageService.default_language
  end

  # Get human-readable language name
  def language_display_name
    LanguageService.native_language_name(preferred_language)
  end

  # ============================================================================
  # SPEAKING PACE PREFERENCE METHODS
  # ============================================================================

  # Default WPM values
  DEFAULT_TARGET_WPM = 140
  DEFAULT_OPTIMAL_WPM_MIN = 130
  DEFAULT_OPTIMAL_WPM_MAX = 150
  DEFAULT_ACCEPTABLE_WPM_MIN = 110
  DEFAULT_ACCEPTABLE_WPM_MAX = 170

  # Deltas for calculating ranges from target
  OPTIMAL_WPM_DELTA = 10
  ACCEPTABLE_WPM_DELTA = 30

  # Get the target WPM or default
  def target_wpm_or_default
    target_wpm || DEFAULT_TARGET_WPM
  end

  # Get the optimal WPM range (target ± 10 WPM)
  # Returns a Range object
  def optimal_wpm_range
    if target_wpm.present?
      (target_wpm - OPTIMAL_WPM_DELTA)..(target_wpm + OPTIMAL_WPM_DELTA)
    else
      DEFAULT_OPTIMAL_WPM_MIN..DEFAULT_OPTIMAL_WPM_MAX
    end
  end

  # Get the acceptable WPM range (target ± 30 WPM)
  # Returns a Range object
  def acceptable_wpm_range
    if target_wpm.present?
      (target_wpm - ACCEPTABLE_WPM_DELTA)..(target_wpm + ACCEPTABLE_WPM_DELTA)
    else
      DEFAULT_ACCEPTABLE_WPM_MIN..DEFAULT_ACCEPTABLE_WPM_MAX
    end
  end

  # Get optimal WPM minimum
  def optimal_wpm_min
    optimal_wpm_range.min
  end

  # Get optimal WPM maximum
  def optimal_wpm_max
    optimal_wpm_range.max
  end

  # Get acceptable WPM minimum
  def acceptable_wpm_min
    acceptable_wpm_range.min
  end

  # Get acceptable WPM maximum
  def acceptable_wpm_max
    acceptable_wpm_range.max
  end

  # ============================================================================
  # SUBSCRIPTION & TRIAL METHODS
  # ============================================================================

  # Check if user can access the app (has active subscription, lifetime access, or valid trial)
  def can_access_app?
    subscription_active? || subscription_lifetime? || trial_active?
  end

  # Check if user has an active paid subscription (any platform)
  def subscription_active?
    stripe_subscription_active? || apple_subscription_active?
  end

  # Check if user has an active Stripe subscription
  def stripe_subscription_active?
    stripe_subscription_id.present? &&
      subscription_status == "active" &&
      (subscription_platform.nil? || subscription_platform == "stripe") &&
      current_period_end&.future?
  end

  # Check if user has an active Apple subscription
  def apple_subscription_active?
    apple_subscription_id.present? &&
      subscription_status == "active" &&
      subscription_platform == "apple" &&
      current_period_end&.future?
  end

  # Check if user's free trial is still valid
  def trial_active?
    subscription_status == "free_trial" && trial_expires_at&.future?
  end

  # Check if trial has expired
  def trial_expired?
    subscription_status == "free_trial" && trial_expires_at&.past?
  end

  # Extend trial based on daily practice
  # Each qualifying session resets the trial to 24 hours from now
  def extend_trial_for_practice!(session)
    # Only extend for users on free trial
    return false unless subscription_free_trial?

    # Only extend if session is at least ~1 minute (55s to account for timing)
    duration_seconds = session.analysis_data&.dig("duration_seconds")&.to_f || 0
    return false unless duration_seconds >= 55

    # Reset trial to 24 hours from now
    new_expiry = 24.hours.from_now

    # Track this qualifying session and reset trial
    update_columns(
      last_qualifying_session_at: session.created_at,
      trial_expires_at: new_expiry
    )
    Rails.logger.info "Trial reset for user #{id} to #{new_expiry} (session #{session.id})"
    true
  end

  # Check if user has completed a practice session today
  def practiced_today?
    sessions.where(completed: true)
            .where("DATE(created_at) = ?", Date.current)
            .where("json_extract(analysis_data, '$.duration_seconds') >= ?", 55)
            .exists?
  end

  # Legacy method - keeping for compatibility
  def extend_trial!
    Rails.logger.info "Legacy extend_trial! called for user #{id} - use extend_trial_for_practice! instead"
    false
  end

  # Get human-readable subscription status
  def subscription_display_status
    case subscription_status
    when "free_trial"
      trial_active? ? "Free Trial (Active)" : "Trial Expired"
    when "lifetime"
      "Lifetime Access"
    when "active"
      platform_text = subscription_platform ? " (#{subscription_platform.titleize})" : ""
      "#{subscription_plan&.titleize} Plan#{platform_text}"
    when "canceled"
      "Canceled"
    when "past_due"
      "Payment Failed"
    else
      "Unknown"
    end
  end

  # Get subscription platform display name
  def subscription_platform_name
    case subscription_platform
    when "stripe"
      "Web (Credit Card)"
    when "apple"
      "Apple App Store"
    else
      "Unknown"
    end
  end

  # Get time remaining in trial (in hours)
  def trial_hours_remaining
    return 0 unless trial_active?
    ((trial_expires_at - Time.current) / 1.hour).ceil
  end

  # Check if user is on monthly plan
  def monthly_plan?
    subscription_plan == "monthly"
  end

  # Check if user is on yearly plan
  def yearly_plan?
    subscription_plan == "yearly"
  end

  # Get Stripe customer (creates if doesn't exist)
  def stripe_customer
    return nil unless stripe_customer_id

    @stripe_customer ||= ::Stripe::Customer.retrieve(stripe_customer_id)
  rescue ::Stripe::InvalidRequestError
    nil
  end

  # Create or retrieve Stripe customer
  def get_or_create_stripe_customer
    return stripe_customer if stripe_customer_id.present?

    customer = ::Stripe::Customer.create(
      email: email,
      name: name,
      metadata: {
        user_id: id
      }
    )

    update!(stripe_customer_id: customer.id)
    customer
  end

  # ============================================================================
  # ADMIN METHODS
  # ============================================================================

  def admin?
    admin == true
  end
end
