class AiCache < ApplicationRecord
  self.primary_key = "key"

  validates :key, presence: true, uniqueness: true
  validates :value, presence: true

  def self.get(cache_key)
    find_by(key: cache_key)&.value
  end

  def self.set(cache_key, cache_value, ttl: nil)
    record = find_or_initialize_by(key: cache_key)
    record.value = cache_value
    record.save!
    record
  end

  def self.delete(cache_key)
    find_by(key: cache_key)&.destroy
  end

  def expired?(ttl_seconds = 86400) # default 24 hours
    return false unless ttl_seconds

    created_at < ttl_seconds.seconds.ago
  end
end
