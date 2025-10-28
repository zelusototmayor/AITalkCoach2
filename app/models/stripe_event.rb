class StripeEvent < ApplicationRecord
  validates :stripe_event_id, presence: true, uniqueness: true
  validates :event_type, presence: true

  # Check if this event has already been processed (idempotency)
  def self.processed?(event_id)
    exists?(stripe_event_id: event_id, processed_at: !nil)
  end

  # Mark event as processed
  def mark_as_processed!
    update!(processed_at: Time.current)
  end
end
