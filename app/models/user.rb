class User < ApplicationRecord
  has_secure_password

  has_many :sessions, dependent: :destroy
  has_many :weekly_focuses, dependent: :destroy, class_name: 'WeeklyFocus'
  has_many :user_issue_embeddings, dependent: :destroy
  has_many :issues, through: :sessions

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true, length: { minimum: 2, maximum: 50 }
  validates :password, length: { minimum: 6 }, if: -> { new_record? || !password.nil? }

  # Password reset methods
  def generate_reset_password_token!
    self.reset_password_token = SecureRandom.urlsafe_base64
    self.reset_password_sent_at = Time.current
    save!(validate: false)
  end

  def reset_password_token_expired?
    return true if reset_password_sent_at.nil?
    reset_password_sent_at < 24.hours.ago
  end

  def reset_password!(new_password)
    self.password = new_password
    self.reset_password_token = nil
    self.reset_password_sent_at = nil
    save!
  end

  def self.find_by_valid_reset_token(token)
    user = find_by(reset_password_token: token)
    return nil if user.nil? || user.reset_password_token_expired?
    user
  end
end
