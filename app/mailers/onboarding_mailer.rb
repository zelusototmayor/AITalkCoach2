class OnboardingMailer < ApplicationMailer
  def welcome(user)
    @user = user
    @app_url = build_app_url

    mail(
      to: @user.email,
      subject: "Welcome to AI Talk Coach! Your journey begins now 🎯"
    )
  end

  private

  def build_app_url
    # Use same logic as UserMailer for consistency
    base_domain = Rails.env.production? ? 'aitalkcoach.com' : 'aitalkcoach.local'
    protocol = Rails.env.production? ? 'https' : 'https' # Always HTTPS (dev has SSL now)
    port = Rails.env.production? ? '' : ':3000'
    "#{protocol}://app.#{base_domain}#{port}/practice"
  end
end
