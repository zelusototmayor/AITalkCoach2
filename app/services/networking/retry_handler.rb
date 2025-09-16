module Networking
  class RetryHandler
    class RetryExhaustedException < StandardError; end
    class NonRetryableError < StandardError; end
    
    # Configuration for different types of operations
    RETRY_CONFIGS = {
      api_call: {
        max_attempts: 5,
        base_delay: 1.0,
        max_delay: 60.0,
        backoff_strategy: :exponential_with_jitter,
        retryable_errors: [
          'HTTP::TimeoutError',
          'HTTP::ConnectionError',
          'Errno::ECONNRESET',
          'Errno::EHOSTUNREACH',
          'Net::ReadTimeout',
          'Net::OpenTimeout',
          'SocketError'
        ],
        retryable_status_codes: [429, 502, 503, 504, 520, 521, 522, 523, 524]
      },
      ai_generation: {
        max_attempts: 4,
        base_delay: 2.0,
        max_delay: 120.0,
        backoff_strategy: :exponential_with_full_jitter,
        retryable_errors: [
          'Ai::Client::RateLimitError',
          'Ai::Client::ClientError',
          'HTTP::TimeoutError'
        ],
        circuit_breaker: true
      },
      file_processing: {
        max_attempts: 3,
        base_delay: 0.5,
        max_delay: 10.0,
        backoff_strategy: :linear,
        retryable_errors: [
          'Errno::ENOENT',
          'Errno::EACCES',
          'IOError'
        ]
      }
    }.freeze
    
    def initialize(operation_type = :api_call, custom_config: nil)
      @config = custom_config || RETRY_CONFIGS[operation_type] || RETRY_CONFIGS[:api_call]
      @operation_type = operation_type
      @circuit_breaker = initialize_circuit_breaker if @config[:circuit_breaker]
    end
    
    def with_retries(**context)
      attempt = 0
      start_time = Time.current
      last_error = nil
      
      begin
        attempt += 1
        
        # Check circuit breaker if configured
        check_circuit_breaker! if @circuit_breaker
        
        # Log retry attempt
        log_retry_attempt(attempt, context) if attempt > 1
        
        result = yield
        
        # Reset circuit breaker on success
        @circuit_breaker&.record_success
        
        # Log successful completion if there were retries
        log_retry_success(attempt, Time.current - start_time, context) if attempt > 1
        
        return result
        
      rescue => error
        last_error = error
        
        # Record failure in circuit breaker
        @circuit_breaker&.record_failure
        
        # Check if error is retryable
        unless retryable_error?(error)
          log_non_retryable_error(error, attempt, context)
          raise NonRetryableError, "Non-retryable error: #{error.class.name} - #{error.message}"
        end
        
        # Check if we've exhausted our attempts
        if attempt >= @config[:max_attempts]
          total_duration = Time.current - start_time
          log_retry_exhausted(attempt, total_duration, error, context)
          
          # Report to monitoring
          Monitoring::ErrorReporter.report_api_error(
            context[:service] || 'unknown',
            'retry_exhausted',
            error,
            context.merge({
              total_attempts: attempt,
              total_duration: total_duration,
              operation_type: @operation_type
            })
          )
          
          raise RetryExhaustedException, "Retry exhausted after #{attempt} attempts: #{error.message}"
        end
        
        # Calculate delay and wait
        delay = calculate_delay(attempt, error)
        log_retry_delay(attempt, delay, error, context)
        sleep(delay)
        
        retry
      end
    end
    
    def self.with_circuit_breaker(service_name, failure_threshold: 5, recovery_timeout: 60, &block)
      handler = new(:api_call, custom_config: {
        max_attempts: 1,
        circuit_breaker: true,
        circuit_breaker_config: {
          service_name: service_name,
          failure_threshold: failure_threshold,
          recovery_timeout: recovery_timeout
        }
      })
      
      handler.with_retries(service: service_name, &block)
    end
    
    private
    
    def retryable_error?(error)
      # Check by error class name
      error_class_name = error.class.name
      return true if @config[:retryable_errors]&.include?(error_class_name)
      
      # Check HTTP status codes if it's an HTTP error
      if error.respond_to?(:response) && error.response&.status
        status_code = error.response.status.to_i
        return true if @config[:retryable_status_codes]&.include?(status_code)
      end
      
      # Check for rate limiting errors (always retryable with backoff)
      return true if error_class_name.include?('RateLimit') || error_class_name.include?('QuotaExceeded')
      
      # Default to non-retryable
      false
    end
    
    def calculate_delay(attempt, error)
      base_delay = @config[:base_delay] || 1.0
      max_delay = @config[:max_delay] || 60.0
      
      # Extract retry-after header if available
      if error.respond_to?(:response) && error.response&.headers
        retry_after = error.response.headers['retry-after']&.to_i
        return [retry_after, max_delay].min if retry_after && retry_after > 0
      end
      
      # Calculate delay based on backoff strategy
      case @config[:backoff_strategy]
      when :exponential_with_jitter
        exponential_backoff_with_jitter(attempt, base_delay, max_delay)
      when :exponential_with_full_jitter
        exponential_backoff_with_full_jitter(attempt, base_delay, max_delay)
      when :linear
        linear_backoff(attempt, base_delay, max_delay)
      when :constant
        base_delay
      else
        exponential_backoff_with_jitter(attempt, base_delay, max_delay)
      end
    end
    
    def exponential_backoff_with_jitter(attempt, base_delay, max_delay)
      delay = base_delay * (2 ** (attempt - 1))
      delay = [delay, max_delay].min
      
      # Add jitter (±25% of the delay)
      jitter_range = delay * 0.25
      jitter = (rand * 2 - 1) * jitter_range
      
      [delay + jitter, 0.1].max # Ensure minimum delay
    end
    
    def exponential_backoff_with_full_jitter(attempt, base_delay, max_delay)
      max_backoff = [base_delay * (2 ** (attempt - 1)), max_delay].min
      rand * max_backoff
    end
    
    def linear_backoff(attempt, base_delay, max_delay)
      delay = base_delay * attempt
      [delay, max_delay].min
    end
    
    def initialize_circuit_breaker
      circuit_config = @config[:circuit_breaker_config] || {}
      CircuitBreaker.new(
        service_name: circuit_config[:service_name] || 'default',
        failure_threshold: circuit_config[:failure_threshold] || 5,
        recovery_timeout: circuit_config[:recovery_timeout] || 60
      )
    end
    
    def check_circuit_breaker!
      return unless @circuit_breaker
      
      if @circuit_breaker.open?
        error_message = "Circuit breaker is open for #{@circuit_breaker.service_name}"
        Rails.logger.warn error_message
        raise NonRetryableError, error_message
      end
    end
    
    def log_retry_attempt(attempt, context)
      Rails.logger.warn "Retry attempt #{attempt}/#{@config[:max_attempts]} for #{@operation_type} (Context: #{context.inspect})"
    end
    
    def log_retry_success(total_attempts, total_duration, context)
      Rails.logger.info "Retry successful after #{total_attempts} attempts in #{total_duration.round(2)}s for #{@operation_type} (Context: #{context.inspect})"
    end
    
    def log_retry_delay(attempt, delay, error, context)
      Rails.logger.warn "Retrying in #{delay.round(2)}s after #{error.class.name}: #{error.message.truncate(100)} (Attempt #{attempt}, Context: #{context.inspect})"
    end
    
    def log_retry_exhausted(attempts, duration, error, context)
      Rails.logger.error "Retry exhausted after #{attempts} attempts in #{duration.round(2)}s for #{@operation_type}. Last error: #{error.class.name}: #{error.message} (Context: #{context.inspect})"
    end
    
    def log_non_retryable_error(error, attempt, context)
      Rails.logger.error "Non-retryable error on attempt #{attempt} for #{@operation_type}: #{error.class.name}: #{error.message} (Context: #{context.inspect})"
    end
    
    # Simple circuit breaker implementation
    class CircuitBreaker
      attr_reader :service_name
      
      def initialize(service_name:, failure_threshold: 5, recovery_timeout: 60)
        @service_name = service_name
        @failure_threshold = failure_threshold
        @recovery_timeout = recovery_timeout
        @failure_count = 0
        @last_failure_time = nil
        @state = :closed # :closed, :open, :half_open
      end
      
      def record_success
        @failure_count = 0
        @state = :closed
      end
      
      def record_failure
        @failure_count += 1
        @last_failure_time = Time.current
        
        if @failure_count >= @failure_threshold
          @state = :open
          Rails.logger.warn "Circuit breaker opened for #{@service_name} after #{@failure_count} failures"
        end
      end
      
      def open?
        case @state
        when :open
          # Check if recovery timeout has passed
          if Time.current - @last_failure_time > @recovery_timeout
            @state = :half_open
            Rails.logger.info "Circuit breaker half-open for #{@service_name}, allowing test request"
            false
          else
            true
          end
        when :half_open
          false # Allow one request to test
        else
          false
        end
      end
    end
  end
end