class Session < ApplicationRecord
  belongs_to :user
  belongs_to :weekly_focus, optional: true
  has_many :issues, dependent: :destroy
  has_many_attached :media_files
  
  validates :title, presence: true
  validates :language, presence: true
  validates :media_kind, inclusion: { in: %w[audio video] }
  validates :processing_state, inclusion: { in: %w[pending processing completed failed] }
  validates :target_seconds, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 300 }
  validates :media_files, presence: { message: "Please record audio or video before creating the session" }
  
  scope :completed, -> { where(completed: true) }
  scope :failed, -> { where(completed: false).where.not(incomplete_reason: nil) }
  
  def analysis_data
    return {} unless analysis_json.present?
    
    JSON.parse(analysis_json)
  rescue JSON::ParserError
    {}
  end
  
  def analysis_data=(data)
    self.analysis_json = data.to_json
  end

  def duration_seconds
    # First try to get duration from analysis data
    analysis_duration = analysis_data['duration_seconds']
    return analysis_duration.to_f if analysis_duration.present?

    # Fallback to converting duration_ms to seconds
    return (duration_ms || 0) / 1000.0
  end
end
