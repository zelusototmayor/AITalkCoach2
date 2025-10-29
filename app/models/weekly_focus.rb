class WeeklyFocus < ApplicationRecord
  self.table_name = "weekly_focuses"

  belongs_to :user
  has_many :sessions, dependent: :nullify

  # Validations
  validates :focus_type, presence: true, inclusion: {
    in: %w[reduce_fillers improve_pace enhance_clarity boost_engagement increase_fluency fix_long_pauses professional_language],
    message: "%{value} is not a valid focus type"
  }
  validates :target_value, presence: true, numericality: { greater_than: 0 }
  validates :starting_value, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :week_start, presence: true
  validates :week_end, presence: true
  validates :target_sessions_per_week, presence: true, numericality: {
    only_integer: true,
    greater_than: 0,
    less_than_or_equal_to: 20
  }
  validates :status, presence: true, inclusion: {
    in: %w[active completed missed],
    message: "%{value} is not a valid status"
  }

  validate :week_end_after_week_start
  validate :one_active_focus_per_user

  # Scopes
  scope :active, -> { where(status: "active") }
  scope :completed, -> { where(status: "completed") }
  scope :for_user, ->(user) { where(user: user) }
  scope :current_week, -> { where("week_start <= ? AND week_end >= ?", Date.current, Date.current) }
  scope :recent, -> { order(week_start: :desc).limit(10) }

  # Class methods
  def self.current_for_user(user)
    for_user(user).active.current_week.first
  end

  def self.create_from_recommendation(user, recommendation)
    focus_area = recommendation[:focus_this_week]&.first
    return nil unless focus_area

    week_start = Date.current.beginning_of_week
    week_end = week_start + 6.days

    create(
      user: user,
      focus_type: focus_area[:type],
      target_value: focus_area[:target_value],
      starting_value: focus_area[:current_value],
      week_start: week_start,
      week_end: week_end,
      target_sessions_per_week: 10,
      status: "active"
    )
  end

  # Instance methods
  def completed_sessions_count
    sessions.where(completed: true).count
  end

  def planned_sessions_today_count
    sessions.where(planned_for_date: Date.current).count
  end

  def completion_percentage
    return 0 if target_sessions_per_week.zero?
    ((completed_sessions_count.to_f / target_sessions_per_week) * 100).round(1)
  end

  def days_remaining
    (week_end - Date.current).to_i
  end

  def is_current?
    Date.current.between?(week_start, week_end) && status == "active"
  end

  def mark_completed!
    update(status: "completed")
  end

  def mark_missed!
    update(status: "missed")
  end

  # Human-readable focus type
  def focus_type_humanized
    case focus_type
    when "reduce_fillers" then "Reduce Filler Words"
    when "improve_pace" then "Improve Speaking Pace"
    when "enhance_clarity" then "Enhance Speech Clarity"
    when "boost_engagement" then "Boost Engagement"
    when "increase_fluency" then "Increase Fluency"
    when "fix_long_pauses" then "Fix Long Pauses"
    when "professional_language" then "Use Professional Language"
    else focus_type.humanize
    end
  end

  private

  def week_end_after_week_start
    if week_end.present? && week_start.present? && week_end <= week_start
      errors.add(:week_end, "must be after week start")
    end
  end

  def one_active_focus_per_user
    return unless status == "active" && user.present?

    existing_active = user.weekly_focuses.active.current_week.where.not(id: id)
    if existing_active.exists?
      errors.add(:base, "User already has an active weekly focus for this week")
    end
  end
end
