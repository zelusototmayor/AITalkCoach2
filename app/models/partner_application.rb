class PartnerApplication < ApplicationRecord
  PARTNER_TYPES = [ "Speech Coach", "Content Creator", "Educator" ].freeze

  validates :name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :partner_type, presence: true, inclusion: { in: PARTNER_TYPES }

  after_create :send_confirmation_email
  after_create :send_to_google_sheet

  private

  def send_confirmation_email
    PartnerMailer.application_received(self).deliver_later
  end

  def send_to_google_sheet
    return unless Rails.application.credentials.dig(:google_sheet, :webhook_url).present?

    webhook_url = Rails.application.credentials.dig(:google_sheet, :webhook_url)
    secret = Rails.application.credentials.dig(:google_sheet, :webhook_secret)

    payload = {
      secret: secret,
      name: name,
      email: email,
      type: partner_type,
      reason: message
    }

    begin
      response = HTTP.timeout(10).post(
        webhook_url,
        json: payload
      )

      Rails.logger.info("Google Sheet webhook response: #{response.status} - #{response.body}")
    rescue StandardError => e
      Rails.logger.error("Failed to send to Google Sheet: #{e.message}")
      # Don't raise the error - we don't want to block the application if the webhook fails
    end
  end
end
