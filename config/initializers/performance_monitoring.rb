# Performance monitoring and optimization configurations

# Enable query analysis in development and staging
if Rails.env.development? || Rails.env.staging?
  # Log slow queries
  ActiveRecord::Base.logger = Logger.new(STDOUT)

  # Enable automatic EXPLAIN for slow queries
  if ENV["ENABLE_QUERY_ANALYSIS"] == "true"
    ActiveRecord::Base.connection.class.prepend(Module.new do
      def execute(sql, *args)
        start_time = Time.current
        result = super
        duration = (Time.current - start_time) * 1000

        if duration > 100 # Log queries taking more than 100ms
          Rails.logger.warn "Slow query (#{duration.round(2)}ms): #{sql.truncate(200)}"

          # Auto-explain complex queries
          if sql.match?(/JOIN|GROUP BY|ORDER BY|LIMIT \d{2,}/) && duration > 250
            # Use safe SQL sanitization to prevent SQL injection
            sanitized_sql = ActiveRecord::Base.connection.quote(sql)
            explain_result = connection.execute("EXPLAIN QUERY PLAN #{sanitized_sql}") rescue nil
            if explain_result
              Rails.logger.info "Query plan: #{explain_result.to_a}"
            end
          end
        end

        result
      end
    end)
  end
end

# Database connection pool optimization
# TODO: Re-enable connection pool monitoring with correct Rails 8 API
# ActiveRecord::ConnectionAdapters::ConnectionPool.class_eval do
#   # Add connection pool monitoring
#   def checkout(checkout_timeout = @checkout_timeout)
#     start_time = Time.current
#     connection = super
#     checkout_duration = (Time.current - start_time) * 1000
#
#     if checkout_duration > 1000 # Log slow checkouts (>1s)
#       Rails.logger.warn "Slow connection checkout: #{checkout_duration.round(2)}ms"
#     end
#
#     connection
#   end
# end

# Memory usage monitoring
if ENV["ENABLE_MEMORY_MONITORING"] == "true"
  # Monitor memory usage every 30 seconds in production
  if Rails.env.production?
    Thread.new do
      loop do
        begin
          # Get current memory usage (if available)
          if defined?(GC) && GC.respond_to?(:stat)
            memory_mb = (GC.stat[:heap_allocated_pages] * GC::INTERNAL_CONSTANTS[:HEAP_PAGE_SIZE]) / (1024.0 * 1024.0)

            # Alert if memory usage is high
            memory_threshold = ENV.fetch("MEMORY_ALERT_THRESHOLD_MB", 512).to_i
            if memory_mb > memory_threshold
              Rails.logger.warn "High memory usage: #{memory_mb.round(2)}MB"

              if defined?(Monitoring::ErrorReporter)
                Monitoring::ErrorReporter.report_performance_issue(
                  "High memory usage",
                  memory_mb.round,
                  memory_threshold,
                  {
                    gc_count: GC.count,
                    heap_pages: GC.stat[:heap_allocated_pages]
                  }
                )
              end
            end
          end
        rescue => e
          Rails.logger.debug "Memory monitoring error: #{e.message}"
        end

        sleep 30
      end
    end
  end
end

# Request performance monitoring
if defined?(ActionController::Base)
  ActionController::Base.class_eval do
    around_action :monitor_request_performance, if: -> { Rails.env.production? && ENV["ENABLE_REQUEST_MONITORING"] == "true" }

    private

    def monitor_request_performance
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      start_memory = measure_memory_usage

      yield

      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end_memory = measure_memory_usage

      duration = (end_time - start_time) * 1000
      memory_used = end_memory - start_memory

      # Log slow requests
      slow_request_threshold = ENV.fetch("SLOW_REQUEST_THRESHOLD_MS", 2000).to_i
      if duration > slow_request_threshold
        Rails.logger.warn "Slow request: #{request.method} #{request.path} took #{duration.round(2)}ms"

        if defined?(Monitoring::ErrorReporter)
          Monitoring::ErrorReporter.report_performance_issue(
            "#{controller_name}##{action_name}",
            duration.round,
            slow_request_threshold,
            {
              method: request.method,
              path: request.path,
              user_agent: request.user_agent&.truncate(100),
              memory_used: memory_used.round(2)
            }
          )
        end
      end

      # Log high memory usage requests
      memory_threshold = ENV.fetch("REQUEST_MEMORY_THRESHOLD_MB", 50).to_i
      if memory_used > memory_threshold
        Rails.logger.warn "High memory request: #{request.method} #{request.path} used #{memory_used.round(2)}MB"
      end
    end

    def measure_memory_usage
      return 0.0 unless defined?(GC)

      GC.stat[:heap_allocated_pages] * GC::INTERNAL_CONSTANTS[:HEAP_PAGE_SIZE] / (1024.0 * 1024.0)
    rescue
      0.0
    end
  end
end

# Background job performance monitoring (already handled in ApplicationJob)

# Cache performance monitoring
if Rails.cache.respond_to?(:stats)
  # Add cache monitoring for supported cache stores
  Rails.application.config.after_initialize do
    if ENV["ENABLE_CACHE_MONITORING"] == "true"
      # Monitor cache hit rates periodically
      Thread.new do
        loop do
          begin
            if Rails.cache.respond_to?(:stats)
              stats = Rails.cache.stats
              if stats && stats[:hit_rate] < 0.7 # Alert if hit rate below 70%
                Rails.logger.warn "Low cache hit rate: #{(stats[:hit_rate] * 100).round(1)}%"
              end
            end
          rescue => e
            Rails.logger.debug "Cache monitoring error: #{e.message}"
          end

          sleep 300 # Check every 5 minutes
        end
      end
    end
  end
end

# Garbage collection optimization
if ENV["OPTIMIZE_GC"] == "true"
  # Tune GC for better performance
  GC.tune_heap_growth_factor = ENV.fetch("RUBY_GC_HEAP_GROWTH_FACTOR", 1.8).to_f
  GC.tune_malloc_limit = ENV.fetch("RUBY_GC_MALLOC_LIMIT", 16_777_216).to_i
  GC.tune_malloc_limit_max = ENV.fetch("RUBY_GC_MALLOC_LIMIT_MAX", 33_554_432).to_i

  # Force GC after large operations if configured
  if ENV["FORCE_GC_AFTER_JOBS"] == "true"
    ActiveJob::Base.class_eval do
      after_perform do |job|
        # Force GC after memory-intensive jobs
        if job.class.name.include?("ProcessJob") || job.class.name.include?("AnalysisJob")
          GC.start(full_mark: false, immediate_sweep: false)
        end
      end
    end
  end
end

Rails.logger.info "Performance monitoring initialized with optimizations enabled"
