class UserMailer < ApplicationMailer
  def password_reset(user)
    @user = user

    # Build reset URL for app subdomain
    base_domain = Rails.env.production? ? 'aitalkcoach.com' : 'aitalkcoach.local'
    protocol = Rails.env.production? ? 'https' : 'http'
    port = Rails.env.production? ? '' : ':3000'

    @reset_url = "#{protocol}://app.#{base_domain}#{port}/auth/password/#{@user.reset_password_token}/edit"

    mail(
      to: @user.email,
      subject: 'Reset your AI Talk Coach password'
    )
  end

  def subscription_charged(user, payment_intent)
    @user = user
    @payment_intent = payment_intent
    @amount = format_currency(payment_intent['amount'])
    @plan = user.subscription_plan
    @next_billing_date = user.current_period_end&.strftime('%B %d, %Y')
    @invoice_date = Time.current.strftime('%B %d, %Y')
    @manage_url = build_app_url + '/subscription'

    mail(
      to: @user.email,
      subject: "Payment Received - AI Talk Coach #{@plan&.titleize} Plan"
    )
  end

  def payment_failed(user, error_message)
    @user = user
    @error_message = error_message
    @update_payment_url = build_app_url + '/subscription'

    mail(
      to: @user.email,
      subject: '⚠️ Payment Issue - AI Talk Coach'
    )
  end

  private

  def format_currency(cents)
    "€#{'%.2f' % (cents / 100.0)}"
  end

  def build_app_url
    base_domain = Rails.env.production? ? 'aitalkcoach.com' : 'aitalkcoach.local'
    protocol = Rails.env.production? ? 'https' : 'https' # Always HTTPS (dev has SSL)
    port = Rails.env.production? ? '' : ':3000'
    "#{protocol}://app.#{base_domain}#{port}"
  end
end
