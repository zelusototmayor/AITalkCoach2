class PartnerMailer < ApplicationMailer
  def application_received(partner_application)
    @partner_application = partner_application

    # Build partners URL
    base_domain = Rails.env.production? ? "aitalkcoach.com" : "aitalkcoach.local"
    protocol = Rails.env.production? ? "https" : "https" # Always HTTPS (dev has SSL)
    port = Rails.env.production? ? "" : ":3000"

    @partners_url = "#{protocol}://#{base_domain}#{port}/partners"

    mail(
      to: @partner_application.email,
      subject: "Thanks for Applying to the AI Talk Coach Partner Program!"
    )
  end
end
