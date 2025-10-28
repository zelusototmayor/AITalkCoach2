class SubscriptionController < ApplicationController
  before_action :require_login

  def create
    plan = params[:plan]&.to_sym

    unless [:monthly, :yearly].include?(plan)
      flash[:error] = 'Invalid subscription plan selected'
      redirect_to pricing_url and return
    end

    begin
      checkout_service = Billing::CheckoutService.new(current_user, plan: plan)
      session = checkout_service.create_checkout_session(
        success_url: subscription_success_url,
        cancel_url: pricing_url
      )

      redirect_to session.url, allow_other_host: true
    rescue ::Stripe::StripeError => e
      Rails.logger.error "Stripe checkout error: #{e.message}"
      Sentry.capture_exception(e) if defined?(Sentry)
      flash[:error] = 'Unable to start checkout. Please try again.'
      redirect_to pricing_url
    end
  end

  def success
    flash[:success] = 'Thank you for subscribing! Your account will be activated shortly.'
    redirect_to app_root_path
  end

  def show
    # Allow viewing for active, lifetime, past_due, or trial users
    unless current_user.subscription_active? || current_user.subscription_lifetime? ||
           current_user.subscription_past_due? || current_user.trial_active?
      redirect_to pricing_url, alert: 'Please start your free trial first', allow_other_host: true and return
    end

    # Trial users: show upgrade options instead of billing details
    if current_user.trial_active?
      @trial_hours_remaining = current_user.trial_hours_remaining
      @practiced_today = current_user.practiced_today?
      @monthly_price = '9.99'
      @yearly_price = '60'
      @yearly_monthly_equivalent = '5'
      @savings_percentage = '50'
      return render :upgrade
    end

    # Lifetime users: show special status, no billing actions
    if current_user.subscription_lifetime?
      @is_lifetime = true
      @subscription = nil
      @upcoming_invoice = nil
      @next_payment_date = nil
      @can_change_plan = false
      return
    end

    # Regular paid users: show full billing details
    @is_lifetime = false
    @subscription = fetch_stripe_subscription
    @upcoming_invoice = fetch_upcoming_invoice
    @next_payment_date = current_user.current_period_end
    @current_plan = current_user.subscription_plan
    @can_change_plan = current_user.subscription_active?

    # Calculate plan pricing for switching options
    @monthly_price = '9.99'
    @yearly_price = '60'
    @other_plan = @current_plan == 'monthly' ? 'yearly' : 'monthly'
    @other_plan_price = @other_plan == 'monthly' ? @monthly_price : @yearly_price
  end

  def manage
    begin
      checkout_service = Billing::CheckoutService.new(current_user, plan: :monthly)
      portal_session = checkout_service.create_portal_session(
        return_url: subscription_url
      )

      redirect_to portal_session.url, allow_other_host: true
    rescue ::Stripe::StripeError => e
      Rails.logger.error "Stripe portal error: #{e.message}"
      flash[:error] = 'Unable to access billing portal. Please try again.'
      redirect_to subscription_path
    end
  end

  private

  def fetch_stripe_subscription
    return nil unless current_user.stripe_subscription_id

    ::Stripe::Subscription.retrieve(current_user.stripe_subscription_id)
  rescue ::Stripe::StripeError => e
    Rails.logger.error "Failed to fetch Stripe subscription: #{e.message}"
    nil
  end

  def fetch_upcoming_invoice
    return nil unless current_user.stripe_subscription_id

    ::Stripe::Invoice.upcoming(
      subscription: current_user.stripe_subscription_id
    )
  rescue ::Stripe::StripeError => e
    Rails.logger.error "Failed to fetch upcoming invoice: #{e.message}"
    nil
  end
end
