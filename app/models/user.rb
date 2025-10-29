class User < ApplicationRecord
  has_secure_password

  has_many :sessions, dependent: :destroy
  has_many :weekly_focuses, dependent: :destroy, class_name: "WeeklyFocus"
  has_many :user_issue_embeddings, dependent: :destroy
  has_many :issues, through: :sessions

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true, length: { minimum: 2, maximum: 50 }
  validates :password, length: { minimum: 6 }, if: -> { new_record? || !password.nil? }

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
  def needs_onboarding?
    !onboarding_completed?
  end

  # Link a demo trial session to the user account
  def link_demo_session(trial_session)
    update(onboarding_demo_session_id: trial_session.id)
  end

  # ============================================================================
  # SUBSCRIPTION & TRIAL METHODS
  # ============================================================================

  # Check if user can access the app (has active subscription, lifetime access, or valid trial)
  def can_access_app?
    subscription_active? || subscription_lifetime? || trial_active?
  end

  # Check if user has an active paid subscription
  def subscription_active?
    subscription_status.in?([ "active" ]) && current_period_end&.future?
  end

  # Check if user's free trial is still valid
  def trial_active?
    subscription_status == "free_trial" && trial_expires_at&.future?
  end

  # Check if trial has expired
  def trial_expired?
    subscription_status == "free_trial" && trial_expires_at&.past?
  end

  # Extend trial based on daily practice (calendar day logic)
  # If user practices on day X, they get free access through end of day X+1
  def extend_trial_for_practice!(session)
    # Only extend for users on free trial
    return false unless subscription_free_trial?

    # Only extend if session is at least 1 minute
    duration_seconds = session.analysis_data&.dig("duration_seconds")&.to_f || 0
    return false unless duration_seconds >= 60

    # Session completed on calendar day = free access through end of next day
    session_date = session.created_at.to_date
    new_expiry = session_date.tomorrow.end_of_day

    # Only extend if it would increase the trial period
    if trial_expires_at.nil? || new_expiry > trial_expires_at
      update_column(:trial_expires_at, new_expiry)
      Rails.logger.info "Trial extended for user #{id} until #{new_expiry} (session on #{session_date})"
      true
    else
      Rails.logger.info "Trial not extended for user #{id} - already expires at #{trial_expires_at}"
      false
    end
  end

  # Check if user has completed a practice session today
  def practiced_today?
    sessions.where(completed: true)
            .where("DATE(created_at) = ?", Date.current)
            .where("json_extract(analysis_data, '$.duration_seconds') >= ?", 60)
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
      "#{subscription_plan&.titleize} Plan"
    when "canceled"
      "Canceled"
    when "past_due"
      "Payment Failed"
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
end
