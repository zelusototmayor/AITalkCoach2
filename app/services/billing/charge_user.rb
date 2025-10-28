module Billing
  class ChargeUser
    MONTHLY_AMOUNT = 999  # €9.99 in cents
    YEARLY_AMOUNT = 6000  # €60 in cents
    MAX_RETRY_ATTEMPTS = 3

    attr_reader :user

    def self.call(user)
      new(user).call
    end

    def initialize(user)
      @user = user
    end

    def call
      validate_user!

      amount = calculate_amount

      begin
        # Create and confirm payment intent
        payment_intent = Stripe::PaymentIntent.create(
          amount: amount,
          currency: 'eur',
          customer: user.stripe_customer_id,
          payment_method: user.stripe_payment_method_id,
          off_session: true,
          confirm: true,
          description: "#{user.subscription_plan.titleize} subscription for #{user.email}",
          metadata: {
            user_id: user.id,
            plan: user.subscription_plan
          }
        )

        if payment_intent.status == 'succeeded'
          handle_successful_charge(payment_intent)
          true
        else
          handle_failed_charge("Payment intent status: #{payment_intent.status}")
          false
        end

      rescue Stripe::CardError => e
        handle_card_error(e)
        false
      rescue Stripe::StripeError => e
        handle_stripe_error(e)
        false
      end
    end

    private

    def validate_user!
      raise ArgumentError, "User must have a Stripe customer ID" unless user.stripe_customer_id.present?
      raise ArgumentError, "User must have a payment method" unless user.stripe_payment_method_id.present?
      raise ArgumentError, "User must have a subscription plan" unless user.subscription_plan.present?
    end

    def calculate_amount
      case user.subscription_plan
      when 'yearly'
        YEARLY_AMOUNT
      when 'monthly'
        MONTHLY_AMOUNT
      else
        raise ArgumentError, "Invalid subscription plan: #{user.subscription_plan}"
      end
    end

    def handle_successful_charge(payment_intent)
      Rails.logger.info "Successfully charged user #{user.id}: #{payment_intent.id}"

      # Calculate next billing date based on plan
      next_billing_date = if user.subscription_plan == 'yearly'
        1.year.from_now
      else
        1.month.from_now
      end

      # Update user to active subscriber
      user.update!(
        subscription_status: 'active',
        subscription_started_at: Time.current,
        current_period_end: next_billing_date
      )

      # Send receipt email
      UserMailer.subscription_charged(user, payment_intent).deliver_later
      Rails.logger.info "Receipt email queued for #{user.email}"
    end

    def handle_failed_charge(reason)
      Rails.logger.error "Failed to charge user #{user.id}: #{reason}"

      # TODO: Implement retry logic and user notification
      # For now, just log the failure
    end

    def handle_card_error(error)
      Rails.logger.error "Card error charging user #{user.id}: #{error.message}"

      # Mark subscription as past_due
      user.update(subscription_status: 'past_due')

      # Send payment failure notification
      UserMailer.payment_failed(user, error.message).deliver_later
      Rails.logger.info "Payment failure email queued for #{user.email}"

      # TODO: Implement retry logic (3 attempts)
      # TODO: After 3 failed attempts, block access
    end

    def handle_stripe_error(error)
      Rails.logger.error "Stripe error charging user #{user.id}: #{error.message}"

      # Log to Sentry if available
      Sentry.capture_exception(error) if defined?(Sentry)
    end
  end
end
