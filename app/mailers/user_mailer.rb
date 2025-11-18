class UserMailer < ApplicationMailer
  def password_reset(user)
    @user = user

    # Build reset URL for app subdomain
    base_domain = Rails.env.production? ? "aitalkcoach.com" : "aitalkcoach.local"
    protocol = Rails.env.production? ? "https" : "http"
    port = Rails.env.production? ? "" : ":3000"

    @reset_url = "#{protocol}://app.#{base_domain}#{port}/auth/password/#{@user.reset_password_token}/edit"

    mail(
      to: @user.email,
      subject: "Reset your AI Talk Coach password"
    )
  end

  def subscription_charged(user, payment_intent)
    @user = user
    @payment_intent = payment_intent
    @amount = format_currency(payment_intent["amount"])
    @plan = user.subscription_plan
    @next_billing_date = user.current_period_end&.strftime("%B %d, %Y")
    @invoice_date = Time.current.strftime("%B %d, %Y")
    @manage_url = build_app_url + "/subscription"

    mail(
      to: @user.email,
      subject: "Payment Received - AI Talk Coach #{@plan&.titleize} Plan"
    )
  end

  def payment_failed(user, error_message)
    @user = user
    @error_message = error_message
    @update_payment_url = build_app_url + "/subscription"

    mail(
      to: @user.email,
      subject: "⚠️ Payment Issue - AI Talk Coach"
    )
  end

  def subscription_canceled(user, reason)
    @user = user
    @reason = reason
    @reactivate_url = build_app_url + "/subscription"

    mail(
      to: @user.email,
      subject: "Subscription Canceled - AI Talk Coach"
    )
  end

  def lifetime_access_granted(user)
    @user = user
    @app_url = build_app_url

    # Create mailto link with pre-filled subject and body
    feedback_subject = "AI Talk Coach Feedback"
    feedback_body = "Hi Jose,\n\n" \
                    "I wanted to share my feedback about AI Talk Coach:\n\n" \
                    "What led me to sign up for AI Talk Coach:\n\n\n" \
                    "What I love about the platform:\n\n\n" \
                    "Features I'd like to see next:\n\n\n" \
                    "Any bugs or issues I've encountered:\n\n\n" \
                    "How AI Talk Coach has helped my communication skills:\n\n\n" \
                    "Best,\n#{@user.name}"

    @feedback_url = "mailto:zsottomayor@gmail.com?subject=#{ERB::Util.url_encode(feedback_subject)}&body=#{ERB::Util.url_encode(feedback_body)}"

    mail(
      to: @user.email,
      subject: "Thank You! Lifetime Free Access Granted"
    )
  end

  def account_credentials(user, password)
    @user = user
    @password = password
    @app_url = build_app_url
    @reset_password_url = "#{build_app_url}/auth/password/new"
    @app_store_url = "https://apps.apple.com/us/app/ai-talk-coach/id6754871317"

    mail(
      to: @user.email,
      subject: "Your AI Talk Coach Account Credentials"
    )
  end

  def link_correction(user)
    @user = user
    @app_url = build_app_url

    mail(
      to: @user.email,
      subject: "Correction: AI Talk Coach Login Link"
    )
  end

  def third_time_charm(user, password = nil)
    @user = user
    @password = password
    @login_url = "https://app.aitalkcoach.com/login"

    mail(
      to: @user.email,
      subject: "Third time is the charm"
    )
  end

  def app_store_launch(user)
    @user = user
    @app_url = build_app_url
    @app_store_url = "https://apps.apple.com/us/app/ai-talk-coach/id6754871317"

    # Create mailto link with pre-filled subject and body for feedback
    feedback_subject = "AI Talk Coach Mobile App Feedback"
    feedback_body = "Hi Jose,\n\n" \
                    "I've been testing the AI Talk Coach mobile app and wanted to share my feedback:\n\n" \
                    "What I love about the mobile version:\n\n\n" \
                    "Issues or bugs I encountered:\n\n\n" \
                    "Features I'd like to see on mobile:\n\n\n" \
                    "How the mobile app compares to the web version:\n\n\n" \
                    "Best,\n#{@user.name}"

    @feedback_url = "mailto:zsottomayor@gmail.com?subject=#{ERB::Util.url_encode(feedback_subject)}&body=#{ERB::Util.url_encode(feedback_body)}"

    mail(
      to: @user.email,
      subject: "AI Talk Coach is now on the App Store!"
    )
  end

  private

  def format_currency(cents)
    "€#{'%.2f' % (cents / 100.0)}"
  end

  def build_app_url
    base_domain = Rails.env.production? ? "aitalkcoach.com" : "aitalkcoach.local"
    protocol = Rails.env.production? ? "https" : "https" # Always HTTPS (dev has SSL)
    port = Rails.env.production? ? "" : ":3000"
    "#{protocol}://app.#{base_domain}#{port}"
  end
end
