module Monitoring
  class JobHealthMonitor
    class << self
      def queue_health_check
        {
          status: determine_overall_queue_health,
          queues: analyze_individual_queues,
          summary: build_health_summary,
          timestamp: Time.current.iso8601,
          alerts: generate_health_alerts
        }
      end

      def failed_jobs_analysis(limit: 100)
        return { error: "SolidQueue not configured" } unless solid_queue_available?

        failed_jobs = SolidQueue::FailedExecution.includes(:job)
                                                .order(failed_at: :desc)
                                                .limit(limit)

        {
          total_failed_jobs: SolidQueue::FailedExecution.count,
          recent_failures: failed_jobs.map { |job| format_failed_job(job) },
          failure_patterns: analyze_failure_patterns(failed_jobs),
          recommendations: generate_failure_recommendations(failed_jobs)
        }
      end

      def queue_performance_metrics
        return { error: "SolidQueue not configured" } unless solid_queue_available?

        {
          queues: SolidQueue::Queue.all.map { |queue| analyze_queue_performance(queue) },
          workers: analyze_worker_performance,
          system_health: {
            cpu_usage: system_cpu_usage,
            memory_usage: system_memory_usage,
            disk_space: system_disk_usage
          }
        }
      end

      def job_latency_analysis
        return { error: "SolidQueue not configured" } unless solid_queue_available?

        recent_jobs = SolidQueue::Job.includes(:ready_execution)
                                   .where(finished_at: 1.hour.ago..Time.current)
                                   .limit(1000)

        {
          average_latency: calculate_average_latency(recent_jobs),
          latency_by_queue: calculate_latency_by_queue(recent_jobs),
          slow_jobs: identify_slow_jobs(recent_jobs),
          recommendations: generate_latency_recommendations
        }
      end

      private

      def solid_queue_available?
        defined?(SolidQueue) && SolidQueue::Job.table_exists?
      rescue
        false
      end

      def determine_overall_queue_health
        return :unknown unless solid_queue_available?

        failed_count = SolidQueue::FailedExecution.count
        pending_count = SolidQueue::ReadyExecution.count

        case
        when failed_count > 50
          :critical
        when failed_count > 10 || pending_count > 100
          :warning
        when failed_count > 0 || pending_count > 50
          :attention
        else
          :healthy
        end
      end

      def analyze_individual_queues
        return [] unless solid_queue_available?

        SolidQueue::Queue.all.map do |queue|
          {
            name: queue.name,
            pending_jobs: queue.size,
            workers: count_active_workers(queue.name),
            status: determine_queue_status(queue),
            last_processed: queue.last_heartbeat_at&.iso8601,
            throughput: calculate_queue_throughput(queue.name)
          }
        end
      rescue
        []
      end

      def build_health_summary
        return {} unless solid_queue_available?

        {
          total_pending: SolidQueue::ReadyExecution.count,
          total_failed: SolidQueue::FailedExecution.count,
          total_completed_today: jobs_completed_today,
          average_processing_time: calculate_average_processing_time,
          success_rate: calculate_success_rate
        }
      rescue
        {}
      end

      def generate_health_alerts
        alerts = []
        return alerts unless solid_queue_available?

        # Check for high failure rate
        recent_failures = SolidQueue::FailedExecution.where(failed_at: 1.hour.ago..Time.current).count
        if recent_failures > 5
          alerts << {
            type: :high_failure_rate,
            severity: :warning,
            message: "#{recent_failures} job failures in the last hour",
            recommendation: "Check error patterns and consider scaling workers"
          }
        end

        # Check for queue backlog
        pending_jobs = SolidQueue::ReadyExecution.count
        if pending_jobs > 100
          alerts << {
            type: :queue_backlog,
            severity: :warning,
            message: "#{pending_jobs} jobs pending execution",
            recommendation: "Consider scaling up workers or optimizing job performance"
          }
        end

        # Check for stale jobs
        stale_jobs = SolidQueue::ReadyExecution.where("created_at < ?", 1.hour.ago).count
        if stale_jobs > 10
          alerts << {
            type: :stale_jobs,
            severity: :attention,
            message: "#{stale_jobs} jobs have been pending for over 1 hour",
            recommendation: "Investigate potential worker issues or job complexity"
          }
        end

        alerts
      rescue
        []
      end

      def format_failed_job(failed_job)
        {
          job_class: failed_job.job.class_name,
          queue_name: failed_job.job.queue_name,
          failed_at: failed_job.failed_at.iso8601,
          error_class: failed_job.error&.dig("class"),
          error_message: failed_job.error&.dig("message")&.truncate(200),
          attempts: failed_job.job.executions || 0,
          job_arguments: extract_job_arguments(failed_job.job)
        }
      rescue
        { error: "Unable to format failed job data" }
      end

      def analyze_failure_patterns(failed_jobs)
        patterns = {
          by_error_class: {},
          by_job_class: {},
          by_queue: {},
          by_time_of_day: Array.new(24, 0)
        }

        failed_jobs.each do |job|
          error_class = job.error&.dig("class") || "Unknown"
          job_class = job.job.class_name
          queue_name = job.job.queue_name
          hour = job.failed_at.hour

          patterns[:by_error_class][error_class] = patterns[:by_error_class][error_class].to_i + 1
          patterns[:by_job_class][job_class] = patterns[:by_job_class][job_class].to_i + 1
          patterns[:by_queue][queue_name] = patterns[:by_queue][queue_name].to_i + 1
          patterns[:by_time_of_day][hour] += 1
        end

        patterns
      rescue
        {}
      end

      def generate_failure_recommendations(failed_jobs)
        recommendations = []

        # Analyze common error patterns
        error_counts = failed_jobs.group_by { |j| j.error&.dig("class") }.transform_values(&:count)

        if error_counts["HTTP::TimeoutError"].to_i > 5
          recommendations << "Consider increasing HTTP timeout values or implementing circuit breakers"
        end

        if error_counts["ActiveRecord::RecordNotFound"].to_i > 3
          recommendations << "Review data consistency and add better validation for record existence"
        end

        if error_counts["Ai::Client::RateLimitError"].to_i > 2
          recommendations << "Implement exponential backoff and consider upgrading API limits"
        end

        recommendations
      end

      def jobs_completed_today
        return 0 unless solid_queue_available?

        SolidQueue::Job.where(finished_at: Date.current.beginning_of_day..Time.current).count
      end

      def calculate_average_processing_time
        return 0 unless solid_queue_available?

        recent_jobs = SolidQueue::Job.where(finished_at: 1.hour.ago..Time.current)
                                   .where.not(created_at: nil, finished_at: nil)

        return 0 if recent_jobs.empty?

        total_time = recent_jobs.sum { |job| job.finished_at - job.created_at }
        (total_time / recent_jobs.count).round(2)
      end

      def calculate_success_rate
        return 100.0 unless solid_queue_available?

        total_jobs = SolidQueue::Job.where(created_at: 24.hours.ago..Time.current).count
        failed_jobs = SolidQueue::FailedExecution.where(failed_at: 24.hours.ago..Time.current).count

        return 100.0 if total_jobs.zero?

        ((total_jobs - failed_jobs).to_f / total_jobs * 100).round(1)
      end

      def extract_job_arguments(job)
        return "N/A" unless job.arguments

        job.arguments.to_s.truncate(100)
      rescue
        "Unable to extract arguments"
      end

      def system_cpu_usage
        return "N/A" unless File.exist?("/proc/loadavg")

        File.read("/proc/loadavg").split.first.to_f.round(2)
      rescue
        "N/A"
      end

      def system_memory_usage
        return "N/A" unless File.exist?("/proc/meminfo")

        meminfo = File.read("/proc/meminfo")
        total = meminfo.match(/MemTotal:\s+(\d+)/)[1].to_i
        available = meminfo.match(/MemAvailable:\s+(\d+)/)[1].to_i
        used_percentage = ((total - available).to_f / total * 100).round(1)
        "#{used_percentage}%"
      rescue
        "N/A"
      end

      def system_disk_usage
        return "N/A" unless Rails.root.exist?

        stat = `df #{Rails.root} 2>/dev/null | tail -1`.split
        return "N/A" if stat.empty?

        stat[4] # Usage percentage
      rescue
        "N/A"
      end
    end
  end
end
