class ApplicationJob < ActiveJob::Base
  # Error handling and monitoring
  retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3
  retry_on ActiveRecord::RecordInvalid, wait: 10.seconds, attempts: 2
  discard_on ActiveJob::DeserializationError
  
  # Job monitoring callbacks
  around_perform :monitor_job_performance
  around_enqueue :track_job_enqueueing
  
  # Custom error classes for job monitoring
  class JobTimeoutError < StandardError; end
  class JobMemoryError < StandardError; end
  
  private
  
  def monitor_job_performance
    job_start_time = Time.current
    job_start_memory = measure_memory_usage
    
    Rails.logger.info build_job_start_message(job_start_time)
    
    begin
      # Set job context for monitoring
      set_job_monitoring_context
      
      # Execute the actual job
      yield
      
      # Log successful completion
      job_duration = Time.current - job_start_time
      job_end_memory = measure_memory_usage
      memory_used = job_end_memory - job_start_memory
      
      Rails.logger.info build_job_success_message(job_duration, memory_used)
      
      # Report performance issues if needed
      check_performance_thresholds(job_duration, memory_used)
      
    rescue StandardError => e
      # Calculate job duration for error context
      job_duration = Time.current - job_start_time
      
      # Report the error with full context
      Monitoring::ErrorReporter.report_job_error(self, e, {
        job_duration: job_duration,
        job_arguments: arguments.to_s.truncate(500),
        queue_name: queue_name,
        job_class: self.class.name,
        executions: executions,
        exception_executions: exception_executions
      })
      
      Rails.logger.error build_job_error_message(e, job_duration)
      
      # Re-raise for ActiveJob's retry/discard logic
      raise
    end
  end
  
  def track_job_enqueueing
    Rails.logger.info "Enqueueing #{self.class.name} with priority #{priority} to queue '#{queue_name}'"
    
    # Set enqueue context for monitoring
    if defined?(Sentry)
      Sentry.configure_scope do |scope|
        scope.set_tag(:job_enqueued, true)
        scope.set_tag(:job_class, self.class.name)
        scope.set_tag(:queue_name, queue_name)
        scope.set_context(:job_arguments, { args: arguments.to_s.truncate(200) })
      end
    end
    
    yield
  rescue StandardError => e
    Rails.logger.error "Failed to enqueue #{self.class.name}: #{e.message}"
    Monitoring::ErrorReporter.report_job_error(self, e, {
      stage: 'enqueue',
      queue_name: queue_name,
      job_arguments: arguments.to_s.truncate(500)
    })
    raise
  end
  
  def set_job_monitoring_context
    if defined?(Sentry)
      Sentry.configure_scope do |scope|
        scope.set_tag(:job_class, self.class.name)
        scope.set_tag(:queue_name, queue_name)
        scope.set_tag(:job_id, job_id)
        scope.set_context(:job_info, {
          queue_name: queue_name,
          priority: priority,
          executions: executions,
          enqueued_at: enqueued_at&.iso8601,
          scheduled_at: scheduled_at&.iso8601
        })
      end
    end
  end
  
  def build_job_start_message(start_time)
    "Starting job: #{self.class.name} [ID: #{job_id}] [Queue: #{queue_name}] [Priority: #{priority}] [Attempt: #{executions + 1}] [Started: #{start_time.iso8601}]"
  end
  
  def build_job_success_message(duration, memory_used)
    "Job completed: #{self.class.name} [ID: #{job_id}] [Duration: #{duration.round(2)}s] [Memory: #{format_memory(memory_used)}] [Status: SUCCESS]"
  end
  
  def build_job_error_message(error, duration)
    "Job failed: #{self.class.name} [ID: #{job_id}] [Duration: #{duration.round(2)}s] [Attempt: #{executions + 1}] [Error: #{error.class.name}] [Message: #{error.message.truncate(200)}]"
  end
  
  def check_performance_thresholds(duration, memory_used)
    # Define performance thresholds
    duration_threshold = performance_threshold(:duration)
    memory_threshold = performance_threshold(:memory)
    
    # Check duration threshold
    if duration > duration_threshold
      Monitoring::ErrorReporter.report_performance_issue(
        "#{self.class.name} execution",
        (duration * 1000).round, # Convert to milliseconds
        (duration_threshold * 1000).round,
        {
          job_id: job_id,
          queue_name: queue_name,
          job_arguments: arguments.to_s.truncate(200)
        }
      )
    end
    
    # Check memory threshold
    if memory_used > memory_threshold
      Monitoring::ErrorReporter.report_performance_issue(
        "#{self.class.name} memory usage",
        memory_used.round,
        memory_threshold.round,
        {
          job_id: job_id,
          queue_name: queue_name,
          memory_formatted: format_memory(memory_used)
        }
      )
    end
  end
  
  def performance_threshold(type)
    case type
    when :duration
      # Different thresholds for different job types
      case self.class.name
      when 'Sessions::ProcessJob' then 300.0 # 5 minutes for analysis jobs
      else 60.0 # 1 minute for other jobs
      end
    when :memory
      50.0 # 50MB memory increase threshold
    end
  end
  
  def measure_memory_usage
    return 0.0 unless defined?(GC)
    
    # Get current memory stats (in MB)
    GC.stat[:heap_allocated_pages] * GC::INTERNAL_CONSTANTS[:HEAP_PAGE_SIZE] / (1024.0 * 1024.0)
  rescue
    0.0
  end
  
  def format_memory(memory_mb)
    if memory_mb > 1024
      "#{(memory_mb / 1024.0).round(1)}GB"
    else
      "#{memory_mb.round(1)}MB"
    end
  end
end
