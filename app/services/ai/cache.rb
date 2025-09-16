module Ai
  class Cache
    class CacheError < StandardError; end
    
    DEFAULT_TTL = 24.hours
    
    def self.get(key, ttl: DEFAULT_TTL)
      cache_record = AiCache.find_by(key: generate_cache_key(key))
      return nil unless cache_record
      
      if cache_record.expired?(ttl.to_i)
        cache_record.destroy
        return nil
      end
      
      parse_cached_value(cache_record.value)
    rescue => e
      Rails.logger.warn "AI Cache get error for key #{key}: #{e.message}"
      nil
    end
    
    def self.set(key, value, ttl: DEFAULT_TTL)
      cache_key = generate_cache_key(key)
      serialized_value = serialize_value(value)
      
      cache_record = AiCache.find_or_initialize_by(key: cache_key)
      cache_record.value = serialized_value
      cache_record.save!
      
      # Schedule cleanup if needed
      schedule_cleanup if should_cleanup?
      
      value
    rescue => e
      Rails.logger.error "AI Cache set error for key #{key}: #{e.message}"
      value # Return original value even if caching fails
    end
    
    def self.delete(key)
      cache_key = generate_cache_key(key)
      AiCache.find_by(key: cache_key)&.destroy
      true
    rescue => e
      Rails.logger.warn "AI Cache delete error for key #{key}: #{e.message}"
      false
    end
    
    def self.exists?(key, ttl: DEFAULT_TTL)
      cache_record = AiCache.find_by(key: generate_cache_key(key))
      return false unless cache_record
      
      !cache_record.expired?(ttl.to_i)
    rescue => e
      Rails.logger.warn "AI Cache exists check error for key #{key}: #{e.message}"
      false
    end
    
    def self.fetch(key, ttl: DEFAULT_TTL)
      cached_value = get(key, ttl: ttl)
      return cached_value if cached_value
      
      return nil unless block_given?
      
      fresh_value = yield
      set(key, fresh_value, ttl: ttl)
      fresh_value
    end
    
    def self.clear_expired(ttl: DEFAULT_TTL)
      expired_count = 0
      
      AiCache.find_each do |cache_record|
        if cache_record.expired?(ttl.to_i)
          cache_record.destroy
          expired_count += 1
        end
      end
      
      Rails.logger.info "AI Cache: Cleared #{expired_count} expired entries"
      expired_count
    rescue => e
      Rails.logger.error "AI Cache cleanup error: #{e.message}"
      0
    end
    
    def self.clear_all
      count = AiCache.count
      AiCache.destroy_all
      Rails.logger.info "AI Cache: Cleared all #{count} entries"
      count
    rescue => e
      Rails.logger.error "AI Cache clear all error: #{e.message}"
      0
    end
    
    def self.stats
      {
        total_entries: AiCache.count,
        oldest_entry: AiCache.minimum(:created_at),
        newest_entry: AiCache.maximum(:created_at),
        total_size_bytes: calculate_total_size
      }
    rescue => e
      Rails.logger.error "AI Cache stats error: #{e.message}"
      { error: e.message }
    end
    
    # Cache key generators for different types of AI requests
    def self.transcription_cache_key(file_hash, options = {})
      options_hash = Digest::MD5.hexdigest(options.to_json)
      "transcription:#{file_hash}:#{options_hash}"
    end
    
    def self.analysis_cache_key(transcript_hash, context = {})
      context_hash = Digest::MD5.hexdigest(context.to_json)
      "analysis:#{transcript_hash}:#{context_hash}"
    end
    
    def self.classification_cache_key(issues_hash, context = {})
      context_hash = Digest::MD5.hexdigest(context.to_json)
      "classification:#{issues_hash}:#{context_hash}"
    end
    
    def self.coaching_cache_key(user_id, profile_hash, issues_hash)
      "coaching:#{user_id}:#{profile_hash}:#{issues_hash}"
    end
    
    def self.embedding_cache_key(text_hash, model = 'text-embedding-3-small')
      "embedding:#{model}:#{text_hash}"
    end
    
    private
    
    def self.generate_cache_key(key)
      # Ensure key is within database limits and normalized
      if key.length > 255
        "#{key[0..200]}:#{Digest::MD5.hexdigest(key)}"
      else
        key.to_s
      end
    end
    
    def self.serialize_value(value)
      {
        data: value,
        type: value.class.name,
        cached_at: Time.current.iso8601,
        version: '1.0'
      }.to_json
    end
    
    def self.parse_cached_value(serialized_value)
      parsed = JSON.parse(serialized_value)
      
      # For now, just return the data. In the future, we could add
      # version checking and type coercion here.
      parsed['data']
    rescue JSON::ParserError
      # Handle legacy cache entries that might be plain strings
      serialized_value
    end
    
    def self.should_cleanup?
      # Run cleanup every 100 cache operations (approximately)
      rand(100) == 0
    end
    
    def self.schedule_cleanup
      # In a real application, you might want to use a background job
      # For now, we'll just do a simple cleanup inline
      Thread.new do
        begin
          clear_expired
        rescue => e
          Rails.logger.error "Background AI cache cleanup error: #{e.message}"
        end
      end
    end
    
    def self.calculate_total_size
      AiCache.sum('LENGTH(value)')
    rescue
      0
    end
  end
end