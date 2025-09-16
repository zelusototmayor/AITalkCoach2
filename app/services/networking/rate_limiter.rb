module Networking
  class RateLimiter
    class RateLimitExceededError < StandardError; end
    
    # Rate limiting configurations for different API providers
    RATE_LIMITS = {
      openai: {
        requests_per_minute: 50,
        requests_per_hour: 3000,
        tokens_per_minute: 200_000,
        retry_after_header: 'retry-after',
        burst_allowance: 10
      },
      deepgram: {
        requests_per_minute: 100,
        requests_per_hour: 5000,
        concurrent_requests: 10,
        retry_after_header: 'x-ratelimit-reset',
        burst_allowance: 20
      }
    }.freeze
    
    def initialize(provider, redis_client: nil)
      @provider = provider.to_sym
      @config = RATE_LIMITS[@provider] || default_config
      @redis = redis_client || Rails.cache
      @key_prefix = "rate_limit:#{@provider}"
    end
    
    def check_rate_limit!(endpoint = 'default', tokens: nil)
      now = Time.current
      
      # Check requests per minute
      rpm_key = "#{@key_prefix}:rpm:#{now.strftime('%Y-%m-%d:%H:%M')}"
      current_rpm = @redis.read(rpm_key).to_i
      
      if current_rpm >= @config[:requests_per_minute]
        raise_rate_limit_error(:requests_per_minute, current_rpm, @config[:requests_per_minute])
      end
      
      # Check requests per hour
      rph_key = "#{@key_prefix}:rph:#{now.strftime('%Y-%m-%d:%H')}"
      current_rph = @redis.read(rph_key).to_i
      
      if current_rph >= @config[:requests_per_hour]
        raise_rate_limit_error(:requests_per_hour, current_rph, @config[:requests_per_hour])
      end
      
      # Check token limits for providers that support it (like OpenAI)
      if tokens && @config[:tokens_per_minute]
        tpm_key = "#{@key_prefix}:tpm:#{now.strftime('%Y-%m-%d:%H:%M')}"
        current_tpm = @redis.read(tpm_key).to_i
        
        if (current_tpm + tokens) > @config[:tokens_per_minute]
          raise_rate_limit_error(:tokens_per_minute, current_tpm + tokens, @config[:tokens_per_minute])
        end
      end
      
      # Increment counters if checks pass
      increment_counters(rpm_key, rph_key, tokens)
      
      true
    end
    
    def record_api_response(response, tokens_used: nil)
      # Record response headers for rate limit information
      if response.respond_to?(:headers)
        store_rate_limit_headers(response.headers)
      end
      
      # Update token usage if provided
      if tokens_used && @config[:tokens_per_minute]
        now = Time.current
        tpm_key = "#{@key_prefix}:tpm:#{now.strftime('%Y-%m-%d:%H:%M')}"
        increment_token_counter(tpm_key, tokens_used)
      end
      
      # Log rate limit status
      log_rate_limit_status(response)
    end
    
    def get_rate_limit_status
      now = Time.current
      
      {
        provider: @provider,
        current_usage: {
          requests_per_minute: @redis.read("#{@key_prefix}:rpm:#{now.strftime('%Y-%m-%d:%H:%M')}").to_i,
          requests_per_hour: @redis.read("#{@key_prefix}:rph:#{now.strftime('%Y-%m-%d:%H')}").to_i,
          tokens_per_minute: @redis.read("#{@key_prefix}:tpm:#{now.strftime('%Y-%m-%d:%H:%M')}").to_i
        },
        limits: @config.slice(:requests_per_minute, :requests_per_hour, :tokens_per_minute),
        next_reset: {
          minute: (now + 1.minute).beginning_of_minute,
          hour: (now + 1.hour).beginning_of_hour
        }
      }
    end
    
    def calculate_backoff_delay(attempt, base_delay: 1.0, max_delay: 300.0)
      # Exponential backoff with jitter
      delay = base_delay * (2 ** (attempt - 1))
      delay = [delay, max_delay].min
      
      # Add jitter (±20% of the delay)
      jitter = delay * 0.2 * (rand * 2 - 1)
      (delay + jitter).round(2)
    end
    
    def self.with_rate_limiting(provider, **options)
      limiter = new(provider)
      
      begin
        # Check rate limits before making request
        limiter.check_rate_limit!(options[:endpoint], tokens: options[:estimated_tokens])
        
        # Execute the API call
        result = yield
        
        # Record the response for rate limit tracking
        limiter.record_api_response(result[:response], tokens_used: result[:tokens_used])
        
        result
      rescue RateLimitExceededError => e
        # Log rate limit violation
        Rails.logger.warn "Rate limit exceeded for #{provider}: #{e.message}"
        Monitoring::ErrorReporter.report_api_error(provider.to_s, 'rate_limit_exceeded', e, options)
        
        raise e
      end
    end
    
    private
    
    def default_config
      {
        requests_per_minute: 30,
        requests_per_hour: 1000,
        retry_after_header: 'retry-after',
        burst_allowance: 5
      }
    end
    
    def increment_counters(rpm_key, rph_key, tokens = nil)
      # Increment request counters
      @redis.write(rpm_key, @redis.read(rpm_key).to_i + 1, expires_in: 1.minute)
      @redis.write(rph_key, @redis.read(rph_key).to_i + 1, expires_in: 1.hour)
      
      # Increment token counter if applicable
      if tokens && @config[:tokens_per_minute]
        now = Time.current
        tpm_key = "#{@key_prefix}:tpm:#{now.strftime('%Y-%m-%d:%H:%M')}"
        increment_token_counter(tpm_key, tokens)
      end
    end
    
    def increment_token_counter(tpm_key, tokens)
      current_tokens = @redis.read(tpm_key).to_i
      @redis.write(tpm_key, current_tokens + tokens, expires_in: 1.minute)
    end
    
    def store_rate_limit_headers(headers)
      # Store rate limit information from response headers
      headers.each do |key, value|
        case key.downcase
        when 'x-ratelimit-remaining-requests', 'x-ratelimit-remaining'
          @redis.write("#{@key_prefix}:remaining:requests", value, expires_in: 1.hour)
        when 'x-ratelimit-remaining-tokens'
          @redis.write("#{@key_prefix}:remaining:tokens", value, expires_in: 1.hour)
        when 'x-ratelimit-reset-requests'
          @redis.write("#{@key_prefix}:reset:requests", value, expires_in: 1.hour)
        when 'x-ratelimit-reset-tokens'
          @redis.write("#{@key_prefix}:reset:tokens", value, expires_in: 1.hour)
        when @config[:retry_after_header]
          @redis.write("#{@key_prefix}:retry_after", value, expires_in: value.to_i.seconds)
        end
      end
    rescue => e
      Rails.logger.warn "Failed to store rate limit headers: #{e.message}"
    end
    
    def log_rate_limit_status(response)
      if response.respond_to?(:headers)
        remaining_requests = response.headers['x-ratelimit-remaining-requests']
        remaining_tokens = response.headers['x-ratelimit-remaining-tokens']
        
        if remaining_requests && remaining_requests.to_i < 10
          Rails.logger.warn "Low API request quota remaining for #{@provider}: #{remaining_requests}"
        end
        
        if remaining_tokens && remaining_tokens.to_i < 1000
          Rails.logger.warn "Low API token quota remaining for #{@provider}: #{remaining_tokens}"
        end
      end
    end
    
    def raise_rate_limit_error(limit_type, current, limit)
      message = case limit_type
               when :requests_per_minute
                 "Rate limit exceeded: #{current}/#{limit} requests per minute"
               when :requests_per_hour
                 "Rate limit exceeded: #{current}/#{limit} requests per hour"
               when :tokens_per_minute
                 "Token limit exceeded: #{current}/#{limit} tokens per minute"
               else
                 "Rate limit exceeded for #{limit_type}"
               end
      
      raise RateLimitExceededError, message
    end
  end
end