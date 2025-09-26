class Admin::HealthController < ApplicationController
  # Skip normal authentication for health checks
  skip_before_action :verify_authenticity_token, only: [:show, :detailed]
  
  def show
    # Basic health check
    render json: {
      status: 'ok',
      timestamp: Time.current.iso8601,
      version: Rails.application.class.module_parent_name.downcase
    }
  end

  def detailed
    health_data = {
      status: 'ok',
      timestamp: Time.current.iso8601,
      checks: {
        database: check_database,
        cache: check_cache,
        storage: check_storage,
        jobs: check_background_jobs,
        memory: check_memory_usage,
        performance: check_performance_metrics,
        ffmpeg_processes: check_ffmpeg_processes
      }
    }

    # Determine overall status
    failed_checks = health_data[:checks].select { |_, check| check[:status] == 'error' }
    if failed_checks.any?
      health_data[:status] = 'error'
      health_data[:errors] = failed_checks.keys
    end

    warning_checks = health_data[:checks].select { |_, check| check[:status] == 'warning' }
    if warning_checks.any? && health_data[:status] == 'ok'
      health_data[:status] = 'warning'
      health_data[:warnings] = warning_checks.keys
    end

    status_code = case health_data[:status]
    when 'ok' then 200
    when 'warning' then 200
    when 'error' then 503
    else 500
    end

    render json: health_data, status: status_code
  end

  private

  def check_database
    start_time = Time.current
    
    begin
      # Test basic connectivity
      ActiveRecord::Base.connection.execute('SELECT 1')
      
      # Check for pending migrations
      pending_migrations = ActiveRecord::Base.connection.migration_context.needs_migration?
      
      response_time = ((Time.current - start_time) * 1000).round(2)
      
      if pending_migrations
        {
          status: 'warning',
          message: 'Database accessible but has pending migrations',
          response_time_ms: response_time,
          pending_migrations: true
        }
      else
        {
          status: 'ok',
          message: 'Database is accessible',
          response_time_ms: response_time,
          pending_migrations: false
        }
      end
    rescue => e
      {
        status: 'error',
        message: "Database connection failed: #{e.message}",
        error: e.class.name
      }
    end
  end

  def check_cache
    begin
      # Test cache write/read
      test_key = "health_check_#{SecureRandom.hex(4)}"
      test_value = "test_#{Time.current.to_i}"
      
      Rails.cache.write(test_key, test_value, expires_in: 30.seconds)
      cached_value = Rails.cache.read(test_key)
      Rails.cache.delete(test_key)
      
      if cached_value == test_value
        {
          status: 'ok',
          message: 'Cache is working correctly',
          store: Rails.cache.class.name
        }
      else
        {
          status: 'warning',
          message: 'Cache write/read test failed',
          store: Rails.cache.class.name
        }
      end
    rescue => e
      {
        status: 'error',
        message: "Cache error: #{e.message}",
        error: e.class.name
      }
    end
  end

  def check_storage
    begin
      # Check if Active Storage is configured and working
      if defined?(ActiveStorage)
        # Try to create a test blob
        test_data = "health_check_#{Time.current.to_i}"
        blob = ActiveStorage::Blob.create_and_upload!(
          io: StringIO.new(test_data),
          filename: 'health_check.txt',
          content_type: 'text/plain'
        )
        
        # Clean up immediately
        blob.purge
        
        {
          status: 'ok',
          message: 'Active Storage is working',
          service: Rails.application.config.active_storage.service
        }
      else
        {
          status: 'warning',
          message: 'Active Storage not configured'
        }
      end
    rescue => e
      {
        status: 'error',
        message: "Storage error: #{e.message}",
        error: e.class.name
      }
    end
  end

  def check_background_jobs
    begin
      # Check if Solid Queue is working (Rails 8 default)
      if defined?(SolidQueue)
        # Get basic queue stats
        queue_stats = {
          total_jobs: SolidQueue::Job.count,
          pending_jobs: SolidQueue::Job.pending.count,
          running_jobs: SolidQueue::Job.running.count,
          failed_jobs: SolidQueue::Job.failed.count
        }

        # Check for stuck jobs (running for more than 10 minutes)
        stuck_jobs = SolidQueue::Job.running.where('created_at < ?', 10.minutes.ago).count

        if stuck_jobs > 0
          {
            status: 'warning',
            message: "#{stuck_jobs} jobs may be stuck",
            **queue_stats,
            stuck_jobs: stuck_jobs
          }
        else
          {
            status: 'ok',
            message: 'Background jobs are processing normally',
            **queue_stats
          }
        end
      else
        {
          status: 'warning',
          message: 'No background job processor detected'
        }
      end
    rescue => e
      {
        status: 'error',
        message: "Background jobs error: #{e.message}",
        error: e.class.name
      }
    end
  end

  def check_memory_usage
    begin
      if defined?(GC) && GC.respond_to?(:stat)
        gc_stats = GC.stat
        memory_mb = (gc_stats[:heap_allocated_pages] * GC::INTERNAL_CONSTANTS[:HEAP_PAGE_SIZE]) / (1024.0 * 1024.0)
        
        memory_threshold = ENV.fetch('MEMORY_ALERT_THRESHOLD_MB', 512).to_i
        
        status = if memory_mb > memory_threshold * 1.2
          'error'
        elsif memory_mb > memory_threshold
          'warning'  
        else
          'ok'
        end

        {
          status: status,
          message: "Memory usage: #{memory_mb.round(2)}MB",
          memory_mb: memory_mb.round(2),
          threshold_mb: memory_threshold,
          gc_count: GC.count,
          heap_pages: gc_stats[:heap_allocated_pages]
        }
      else
        {
          status: 'warning',
          message: 'Memory monitoring not available'
        }
      end
    rescue => e
      {
        status: 'error',
        message: "Memory check error: #{e.message}",
        error: e.class.name
      }
    end
  end

  def check_performance_metrics
    begin
      # Check recent session processing performance
      recent_sessions = Session.where('created_at >= ?', 24.hours.ago)
      
      total_sessions = recent_sessions.count
      completed_sessions = recent_sessions.where(completed: true).count
      failed_sessions = recent_sessions.where(completed: false).where.not(incomplete_reason: nil).count
      
      success_rate = total_sessions > 0 ? (completed_sessions.to_f / total_sessions * 100).round(1) : 100
      
      # Calculate average processing time for completed sessions
      avg_processing_time = if completed_sessions > 0
        completed_processing_times = recent_sessions.where(completed: true)
          .where.not(processing_started_at: nil)
          .pluck(:processing_started_at, :updated_at)
          .map { |start, finish| finish - start }
        
        avg_processing_time = completed_processing_times.empty? ? nil : (completed_processing_times.sum / completed_processing_times.length)
        avg_processing_time&.round(1)
      else
        nil
      end

      status = if success_rate < 80
        'error'
      elsif success_rate < 95
        'warning'
      else
        'ok'
      end

      {
        status: status,
        message: "#{success_rate}% success rate in last 24h",
        period: '24h',
        total_sessions: total_sessions,
        completed_sessions: completed_sessions,
        failed_sessions: failed_sessions,
        success_rate: success_rate,
        avg_processing_time_seconds: avg_processing_time
      }
    rescue => e
      {
        status: 'error',
        message: "Performance metrics error: #{e.message}",
        error: e.class.name
      }
    end
  end

  def check_ffmpeg_processes
    begin
      # Count running FFmpeg processes (similar to imagesweep browser monitoring)
      ffmpeg_processes = `pgrep -f "ffmpeg" | wc -l`.to_i

      # Get detailed process info
      if ffmpeg_processes > 0
        process_details = `ps aux | grep ffmpeg | grep -v grep`.split("\n")

        # Check for long-running processes (over 10 minutes like imagesweep timeout logic)
        long_running_count = process_details.count do |process|
          # Extract process start time and calculate duration
          # This is a simplified check - in production you might want more robust parsing
          true # For now, count all as potentially long-running
        end
      else
        process_details = []
        long_running_count = 0
      end

      # Determine status based on process count (similar to imagesweep thresholds)
      status = if ffmpeg_processes > 10
        'error'  # Too many processes, likely accumulating
      elsif ffmpeg_processes > 5
        'warning'  # Getting high, monitor closely
      else
        'ok'  # Normal level
      end

      {
        status: status,
        message: "#{ffmpeg_processes} FFmpeg processes running",
        total_processes: ffmpeg_processes,
        long_running_processes: long_running_count,
        details: ffmpeg_processes > 0 ? process_details.first(3) : []  # Show first 3 for debugging
      }
    rescue => e
      {
        status: 'error',
        message: "FFmpeg process check failed: #{e.message}",
        error: e.class.name
      }
    end
  end
end