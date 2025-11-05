module Billing
  class RevenuecatWebhookHandler
    attr_reader :event_data

    def initialize(event_data)
      @event_data = event_data
    end

    def process
      event_type = event_data["type"]

      Rails.logger.info "Processing RevenueCat webhook: #{event_type}"

      # Process based on event type
      case event_type
      when "INITIAL_PURCHASE"
        handle_initial_purchase
      when "RENEWAL"
        handle_renewal
      when "CANCELLATION"
        handle_cancellation
      when "EXPIRATION"
        handle_expiration
      when "PRODUCT_CHANGE"
        handle_product_change
      when "BILLING_ISSUE"
        handle_billing_issue
      else
        Rails.logger.info "Unhandled RevenueCat event type: #{event_type}"
        return true
      end

      true
    rescue StandardError => e
      Rails.logger.error "Error processing RevenueCat webhook: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      Sentry.capture_exception(e) if defined?(Sentry)
      false
    end

    private

    def handle_initial_purchase
      user = find_user_by_app_user_id

      return unless user

      product_id = event_data.dig("product_id")
      expires_date = event_data.dig("expiration_at_ms")

      plan = plan_from_product_id(product_id)

      Rails.logger.info "Initial purchase for user #{user.id}: product=#{product_id}, plan=#{plan}"

      user.update!(
        subscription_status: "active",
        subscription_plan: plan,
        subscription_platform: "apple",
        apple_subscription_id: event_data.dig("id"),
        revenuecat_customer_id: event_data.dig("app_user_id"),
        current_period_end: expires_date ? Time.at(expires_date / 1000) : nil,
        subscription_started_at: Time.current
      )
    end

    def handle_renewal
      user = find_user_by_app_user_id
      return unless user

      expires_date = event_data.dig("expiration_at_ms")

      Rails.logger.info "Renewal for user #{user.id}"

      user.update!(
        subscription_status: "active",
        current_period_end: expires_date ? Time.at(expires_date / 1000) : nil
      )
    end

    def handle_cancellation
      user = find_user_by_app_user_id
      return unless user

      expires_date = event_data.dig("expiration_at_ms")

      Rails.logger.info "Cancellation for user #{user.id}"

      # User still has access until expiration date
      user.update!(
        subscription_status: "canceled",
        current_period_end: expires_date ? Time.at(expires_date / 1000) : nil
      )
    end

    def handle_expiration
      user = find_user_by_app_user_id
      return unless user

      Rails.logger.info "Expiration for user #{user.id}"

      # Subscription has expired, revert to trial
      user.update!(
        subscription_status: "free_trial",
        current_period_end: nil,
        apple_subscription_id: nil
      )
    end

    def handle_product_change
      user = find_user_by_app_user_id
      return unless user

      new_product_id = event_data.dig("new_product_id")
      expires_date = event_data.dig("expiration_at_ms")

      plan = plan_from_product_id(new_product_id)

      Rails.logger.info "Product change for user #{user.id}: new_product=#{new_product_id}, plan=#{plan}"

      user.update!(
        subscription_plan: plan,
        current_period_end: expires_date ? Time.at(expires_date / 1000) : nil
      )
    end

    def handle_billing_issue
      user = find_user_by_app_user_id
      return unless user

      Rails.logger.info "Billing issue for user #{user.id}"

      user.update!(
        subscription_status: "past_due"
      )

      # TODO: Send email notification to user about billing issue
      # UserMailer.billing_issue(user).deliver_later
    end

    def find_user_by_app_user_id
      app_user_id = event_data.dig("app_user_id")

      return nil if app_user_id.blank?

      # Try to find by RevenueCat customer ID first
      user = User.find_by(revenuecat_customer_id: app_user_id)

      # If not found, try to find by user ID (app_user_id should be user.id.to_s)
      user ||= User.find_by(id: app_user_id.to_i) if app_user_id.to_i.to_s == app_user_id

      if user.nil?
        Rails.logger.warn "User not found for RevenueCat app_user_id: #{app_user_id}"
      end

      user
    end

    def plan_from_product_id(product_id)
      case product_id
      when "02"
        "monthly"
      when "03"
        "yearly"
      else
        Rails.logger.warn "Unknown product_id: #{product_id}, defaulting to monthly"
        "monthly"
      end
    end
  end
end
