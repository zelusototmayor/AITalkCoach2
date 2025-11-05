class BlogPost < ApplicationRecord
  has_rich_text :content
  has_one_attached :featured_image

  # Validations
  validates :title, presence: true, length: { maximum: 200 }
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9\-]+\z/, message: "only allows lowercase letters, numbers, and hyphens" }
  validates :excerpt, length: { maximum: 500 }
  validates :meta_description, length: { maximum: 160 }

  # Callbacks
  before_validation :generate_slug, if: -> { slug.blank? && title.present? }
  before_save :set_published_at, if: -> { will_save_change_to_published? && published }
  before_save :calculate_reading_time

  # Scopes
  scope :published, -> { where(published: true).where.not(published_at: nil) }
  scope :drafts, -> { where(published: false) }
  scope :recent, -> { order(published_at: :desc) }
  scope :by_date, -> { order(published_at: :desc) }

  def to_param
    slug
  end

  def published?
    published && published_at.present?
  end

  private

  def generate_slug
    base_slug = title.parameterize
    slug_candidate = base_slug
    counter = 1

    while BlogPost.exists?(slug: slug_candidate)
      slug_candidate = "#{base_slug}-#{counter}"
      counter += 1
    end

    self.slug = slug_candidate
  end

  def set_published_at
    self.published_at = Time.current if published? && published_at.nil?
  end

  def calculate_reading_time
    return unless content.present?

    # Extract plain text from rich text
    text = content.body.to_plain_text

    # Average reading speed: 200 words per minute
    words = text.split.size
    self.reading_time = (words / 200.0).ceil
    self.reading_time = 1 if reading_time < 1 # Minimum 1 minute
  end
end
