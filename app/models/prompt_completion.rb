class PromptCompletion < ApplicationRecord
  belongs_to :user
  belongs_to :session, optional: true

  validates :prompt_identifier, presence: true
  validates :completed_at, presence: true
  validates :prompt_identifier, uniqueness: { scope: :user_id }

  scope :for_user, ->(user) { where(user: user) }
  scope :completed_after, ->(date) { where("completed_at >= ?", date) }
  scope :recent, -> { order(completed_at: :desc) }

  # Check if a specific prompt has been completed by a user
  def self.completed?(user, prompt_identifier)
    exists?(user: user, prompt_identifier: prompt_identifier)
  end

  # Get all completed prompt identifiers for a user
  def self.completed_identifiers(user)
    where(user: user).pluck(:prompt_identifier)
  end
end
