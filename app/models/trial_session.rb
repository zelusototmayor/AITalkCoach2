class TrialSession < ApplicationRecord
  has_many_attached :media_files

  serialize :analysis_data, coder: JSON

  validates :token, presence: true, uniqueness: true
  validates :title, presence: true
  validates :language, presence: true
  validates :media_kind, presence: true
  validates :expires_at, presence: true

  before_validation :generate_token, on: :create
  before_validation :set_expiration, on: :create

  scope :unexpired, -> { where("expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at <= ?", Time.current) }
  scope :pending, -> { where(processing_state: "pending") }
  scope :processing, -> { where(processing_state: "processing") }
  scope :completed, -> { where(processing_state: "completed") }
  scope :failed, -> { where(processing_state: "failed") }

  enum :processing_state, {
    pending: "pending",
    processing: "processing",
    completed: "completed",
    failed: "failed"
  }, suffix: true

  def to_param
    token
  end

  def expired?
    expires_at <= Time.current
  end

  def processing?
    processing_state.in?([ "pending", "processing" ])
  end

  def duration_seconds
    return 0 unless duration_ms
    duration_ms / 1000.0
  end

  # Trial-specific data accessors (limited compared to full sessions)
  def transcript
    analysis_data&.dig("transcript")
  end

  def wpm
    analysis_data&.dig("wpm")
  end

  def filler_count
    analysis_data&.dig("filler_count")
  end

  def filler_rate
    return 0 unless filler_count && transcript
    word_count = transcript.split.length
    return 0 if word_count == 0
    (filler_count.to_f / word_count * 100).round(1)
  end

  def clarity_score
    # Simple calculation for trial users
    return 85 unless filler_rate
    base_score = 95
    penalty = filler_rate * 2
    [ base_score - penalty, 0 ].max
  end

  def filler_words_per_minute
    return 0 unless filler_count && duration_seconds && duration_seconds > 0
    (filler_count / (duration_seconds / 60.0)).round(1)
  end

  # Calculate overall benchmark score (0-100)
  # This is used in onboarding to show a single "overall" metric
  def overall_benchmark_score
    return nil unless clarity_score && wpm && filler_rate

    # Start with clarity score as the base (weighted 50%)
    score = clarity_score * 0.5

    # Add pace score (weighted 30%)
    # Optimal range is 140-180 WPM, score 100% in that range
    pace_score = if wpm >= 140 && wpm <= 180
      100
    elsif wpm < 140
      # Below optimal - scale down
      [ 100 - (140 - wpm) * 2, 0 ].max
    else
      # Above optimal - scale down
      [ 100 - (wpm - 180) * 2, 0 ].max
    end
    score += pace_score * 0.3

    # Add filler rate score (weighted 20%)
    # Target is < 3%, score decreases as filler rate increases
    filler_score = if filler_rate < 3
      100
    else
      [ 100 - (filler_rate - 3) * 10, 0 ].max
    end
    score += filler_score * 0.2

    score.round
  end

  # Class methods
  def self.cleanup_expired
    expired.destroy_all
  end

  def self.generate_secure_token
    SecureRandom.urlsafe_base64(32)
  end

  # Estimate processing time based on audio length
  def estimated_processing_seconds
    return 30 if duration_ms.blank?

    # Base time of 20 seconds + 1.5 seconds per second of audio
    base_time = 20
    audio_seconds = duration_seconds
    processing_time = base_time + (audio_seconds * 1.5)

    # Cap at 2 minutes for very long recordings
    [ processing_time, 120 ].min.round
  end

  def estimated_completion_time
    return "Starting soon..." if processing_state == "pending"
    return "Done" if processing_state.in?([ "completed", "failed" ])

    seconds = estimated_processing_seconds
    if seconds < 60
      "~#{seconds} seconds"
    else
      minutes = (seconds / 60.0).round
      "~#{minutes} minute#{'s' if minutes != 1}"
    end
  end

  private

  def generate_token
    return if token.present?

    loop do
      self.token = self.class.generate_secure_token
      break unless self.class.exists?(token: token)
    end
  end

  def set_expiration
    # Trial sessions expire after 24 hours
    self.expires_at = 24.hours.from_now
  end
end
