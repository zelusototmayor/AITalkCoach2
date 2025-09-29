class User < ApplicationRecord
  has_secure_password

  has_many :sessions, dependent: :destroy
  has_many :user_issue_embeddings, dependent: :destroy
  has_many :issues, through: :sessions

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true, length: { minimum: 2, maximum: 50 }
  validates :password, length: { minimum: 6 }, if: -> { new_record? || !password.nil? }
end
