module Billing
  class CheckoutService
    PRICE_IDS = {
      monthly: ENV.fetch("STRIPE_MONTHLY_PRICE_ID", "price_monthly_placeholder"),
      yearly: ENV.fetch("STRIPE_YEARLY_PRICE_ID", "price_yearly_placeholder")
    }.freeze

    attr_reader :user, :plan

    def initialize(user, plan:)
      @user = user
      @plan = plan.to_sym
    end

    def create_checkout_session(success_url:, cancel_url:)
      validate_plan!

      customer = user.get_or_create_stripe_customer

      ::Stripe::Checkout::Session.create(
        customer: customer.id,
        mode: "subscription",
        line_items: [ {
          price: price_id,
          quantity: 1
        } ],
        success_url: success_url,
        cancel_url: cancel_url,
        allow_promotion_codes: true,
        billing_address_collection: "auto",
        metadata: {
          user_id: user.id,
          plan: plan
        },
        subscription_data: {
          metadata: {
            user_id: user.id,
            plan: plan
          }
        }
      )
    end

    def create_portal_session(return_url:)
      customer = user.get_or_create_stripe_customer

      ::Stripe::BillingPortal::Session.create(
        customer: customer.id,
        return_url: return_url
      )
    end

    private

    def validate_plan!
      unless PRICE_IDS.key?(plan)
        raise ArgumentError, "Invalid plan: #{plan}. Must be one of: #{PRICE_IDS.keys.join(', ')}"
      end
    end

    def price_id
      PRICE_IDS[plan]
    end
  end
end
