class PartnerApplication < ApplicationRecord
  PARTNER_TYPES = [ "Speech Coach", "Content Creator", "Educator" ].freeze

  validates :name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :partner_type, presence: true, inclusion: { in: PARTNER_TYPES }

  after_create :send_confirmation_email

  private

  def send_confirmation_email
    PartnerMailer.application_received(self).deliver_later
  end
end
