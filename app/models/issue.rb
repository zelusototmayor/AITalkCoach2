class Issue < ApplicationRecord
  belongs_to :session
  has_one :user, through: :session
  
  validates :kind, presence: true
  validates :start_ms, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :end_ms, presence: true, numericality: { greater_than: :start_ms }
  validates :source, inclusion: { in: %w[rule ai] }
  
  scope :by_kind, ->(kind) { where(kind: kind) }
  scope :by_source, ->(source) { where(source: source) }
  scope :in_timeframe, ->(start_ms, end_ms) { where(start_ms: start_ms..end_ms).or(where(end_ms: start_ms..end_ms)) }
  
  def duration_ms
    end_ms - start_ms
  end
  
  def duration_seconds
    duration_ms / 1000.0
  end
end
