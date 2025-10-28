class PricingController < ApplicationController
  # Pricing page is public (no authentication required)

  def index
    @monthly_price = '9.99'
    @yearly_price = '60'
    @yearly_monthly_equivalent = '5'
    @savings_percentage = '50'

    # If user is logged in, show their current plan
    if logged_in?
      @current_plan = current_user.subscription_plan
      @subscription_status = current_user.subscription_display_status
      @trial_hours_remaining = current_user.trial_hours_remaining if current_user.trial_active?
    end
  end
end
