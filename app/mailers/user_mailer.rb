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
end
