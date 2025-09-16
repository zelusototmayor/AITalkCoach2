module Monitoring
  class ErrorReporter
    class << self
      def report_service_error(service, exception, context = {})
        Rails.logger.error build_error_message(service, exception, context)
        
        if defined?(Sentry) && should_report_to_sentry?(exception)
          Sentry.with_scope do |scope|
            scope.set_tag(:service, service.class.name)
            scope.set_context(:service_context, context)
            scope.set_level(:error)
            Sentry.capture_exception(exception)
          end
        end
      end
      
      def report_job_error(job, exception, context = {})
        Rails.logger.error build_job_error_message(job, exception, context)
        
        if defined?(Sentry) && should_report_to_sentry?(exception)
          Sentry.with_scope do |scope|
            scope.set_tag(:job, job.class.name)
            scope.set_context(:job_context, context.merge(
              job_id: job.job_id,
              queue_name: job.queue_name,
              priority: job.priority
            ))
            scope.set_level(:error)
            Sentry.capture_exception(exception)
          end
        end
      end
      
      def report_api_error(api_name, endpoint, exception, context = {})
        Rails.logger.error build_api_error_message(api_name, endpoint, exception, context)
        
        if defined?(Sentry) && should_report_to_sentry?(exception)
          Sentry.with_scope do |scope|
            scope.set_tag(:api, api_name)
            scope.set_tag(:endpoint, endpoint)
            scope.set_context(:api_context, context)
            scope.set_level(:warning) # API errors might be temporary
            Sentry.capture_exception(exception)
          end
        end
      end
      
      def report_performance_issue(operation, duration, threshold, context = {})
        message = "Performance issue: #{operation} took #{duration}ms (threshold: #{threshold}ms)"
        Rails.logger.warn message
        
        if defined?(Sentry)
          Sentry.with_scope do |scope|
            scope.set_tag(:performance_issue, true)
            scope.set_context(:performance, {
              operation: operation,
              duration: duration,
              threshold: threshold
            }.merge(context))
            scope.set_level(:warning)
            Sentry.capture_message(message)
          end
        end
      end
      
      def report_security_event(event_type, details = {})
        message = "Security event: #{event_type}"
        Rails.logger.warn message
        
        if defined?(Sentry)
          Sentry.with_scope do |scope|
            scope.set_tag(:security_event, event_type)
            scope.set_context(:security, details)
            scope.set_level(:warning)
            Sentry.capture_message(message)
          end
        end
      end
      
      private
      
      def build_error_message(service, exception, context)
        [
          "Service Error:",
          "Service: #{service.class.name}",
          "Exception: #{exception.class} - #{exception.message}",
          "Context: #{context.inspect}",
          "Backtrace: #{exception.backtrace&.first(5)&.join(', ')}"
        ].join(" | ")
      end
      
      def build_job_error_message(job, exception, context)
        [
          "Job Error:",
          "Job: #{job.class.name}",
          "Job ID: #{job.job_id}",
          "Queue: #{job.queue_name}",
          "Exception: #{exception.class} - #{exception.message}",
          "Context: #{context.inspect}"
        ].join(" | ")
      end
      
      def build_api_error_message(api_name, endpoint, exception, context)
        [
          "API Error:",
          "API: #{api_name}",
          "Endpoint: #{endpoint}",
          "Exception: #{exception.class} - #{exception.message}",
          "Context: #{context.inspect}"
        ].join(" | ")
      end
      
      def should_report_to_sentry?(exception)
        # Don't report test exceptions or common user errors to Sentry
        ignored_exceptions = [
          'ActiveRecord::RecordNotFound',
          'ActionController::ParameterMissing',
          'ActionController::BadRequest'
        ]
        
        !ignored_exceptions.include?(exception.class.name)
      end
    end
  end
end