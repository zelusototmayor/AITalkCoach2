class User < ApplicationRecord
  has_many :sessions, dependent: :destroy
  has_many :user_issue_embeddings, dependent: :destroy
  has_many :issues, through: :sessions
  
  validates :email, presence: true, uniqueness: true
end
