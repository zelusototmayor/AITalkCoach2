module Billing
  class WebhookHandler
    attr_reader :event

    def initialize(event)
      @event = event
    end

    def process
      # Check if event already processed (idempotency)
      if StripeEvent.processed?(event.id)
        Rails.logger.info "Stripe event #{event.id} already processed, skipping"
        return true
      end

      # Store event for idempotency
      stripe_event = StripeEvent.create!(
        stripe_event_id: event.id,
        event_type: event.type,
        payload: event.to_json
      )

      # Process based on event type
      case event.type
      when 'customer.subscription.created'
        handle_subscription_created
      when 'customer.subscription.updated'
        handle_subscription_updated
      when 'customer.subscription.deleted'
        handle_subscription_deleted
      when 'invoice.payment_succeeded'
        handle_payment_succeeded
      when 'invoice.payment_failed'
        handle_payment_failed
      else
        Rails.logger.info "Unhandled Stripe event type: #{event.type}"
      end

      # Mark as processed
      stripe_event.mark_as_processed!
      true
    rescue StandardError => e
      Rails.logger.error "Error processing Stripe webhook: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      Sentry.capture_exception(e) if defined?(Sentry)
      false
    end

    private

    def handle_subscription_created
      subscription = event.data.object
      user = find_user_by_customer_id(subscription.customer)
      return unless user

      Rails.logger.info "Subscription created for user #{user.id}: #{subscription.id}"

      user.update!(
        stripe_subscription_id: subscription.id,
        subscription_status: 'active',
        subscription_plan: plan_from_subscription(subscription),
        subscription_started_at: Time.at(subscription.current_period_start),
        current_period_end: Time.at(subscription.current_period_end)
      )
    end

    def handle_subscription_updated
      subscription = event.data.object
      user = find_user_by_subscription_id(subscription.id)
      return unless user

      Rails.logger.info "Subscription updated for user #{user.id}: #{subscription.id}"

      # Map Stripe status to our status
      status = case subscription.status
               when 'active' then 'active'
               when 'canceled', 'unpaid' then 'canceled'
               when 'past_due' then 'past_due'
               else 'active'
               end

      user.update!(
        subscription_status: status,
        subscription_plan: plan_from_subscription(subscription),
        current_period_end: Time.at(subscription.current_period_end)
      )
    end

    def handle_subscription_deleted
      subscription = event.data.object
      user = find_user_by_subscription_id(subscription.id)
      return unless user

      Rails.logger.info "Subscription deleted for user #{user.id}: #{subscription.id}"

      user.update!(
        subscription_status: 'canceled',
        current_period_end: Time.at(subscription.current_period_end)
      )
    end

    def handle_payment_succeeded
      invoice = event.data.object
      user = find_user_by_customer_id(invoice.customer)
      return unless user

      Rails.logger.info "Payment succeeded for user #{user.id}: #{invoice.id}"

      # Update period end if this is a subscription invoice
      if invoice.subscription
        subscription = ::Stripe::Subscription.retrieve(invoice.subscription)
        user.update!(
          current_period_end: Time.at(subscription.current_period_end),
          subscription_status: 'active'
        )
      end
    end

    def handle_payment_failed
      invoice = event.data.object
      user = find_user_by_customer_id(invoice.customer)
      return unless user

      Rails.logger.info "Payment failed for user #{user.id}: #{invoice.id}"

      user.update!(subscription_status: 'past_due')

      # TODO: Send email notification to user about failed payment
    end

    def find_user_by_customer_id(customer_id)
      User.find_by(stripe_customer_id: customer_id)
    end

    def find_user_by_subscription_id(subscription_id)
      User.find_by(stripe_subscription_id: subscription_id)
    end

    def plan_from_subscription(subscription)
      return nil if subscription.items.data.empty?

      price = subscription.items.data.first.price

      # Check interval to determine plan type
      case price.recurring&.interval
      when 'month'
        'monthly'
      when 'year'
        'yearly'
      else
        'monthly' # default
      end
    end
  end
end
