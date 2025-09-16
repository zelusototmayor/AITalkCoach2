class Session < ApplicationRecord
  belongs_to :user
  has_many :issues, dependent: :destroy
  has_many_attached :media_files
  
  validates :title, presence: true
  validates :language, presence: true
  validates :media_kind, inclusion: { in: %w[audio video] }
  validates :processing_state, inclusion: { in: %w[pending processing completed failed] }
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
end
