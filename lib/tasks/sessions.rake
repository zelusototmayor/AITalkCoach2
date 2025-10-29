namespace :sessions do
  desc "Check for stuck sessions and mark them as failed"
  task check_stuck: :environment do
    stuck_timeout = 30.minutes

    stuck_sessions = Session.where(processing_state: "processing")
                           .where("updated_at < ?", stuck_timeout.ago)

    if stuck_sessions.any?
      puts "Found #{stuck_sessions.count} stuck sessions:"

      stuck_sessions.each do |session|
        duration = Time.current - session.updated_at
        puts "  Session #{session.id}: stuck for #{duration.to_i / 60} minutes"

        session.update!(
          processing_state: "failed",
          completed: false,
          incomplete_reason: "Processing timeout after #{duration.to_i / 60} minutes - possible job queue issue"
        )

        puts "  → Marked session #{session.id} as failed"
      end
    else
      puts "No stuck sessions found"
    end
  end

  desc "Check job queue health"
  task check_queue_health: :environment do
    adapter = Rails.application.config.active_job.queue_adapter
    puts "Active Job adapter: #{adapter}"

    case adapter
    when :inline
      puts "✓ Jobs execute immediately (inline adapter)"
    when :solid_queue
      if defined?(SolidQueue)
        pending = SolidQueue::ReadyExecution.count
        failed = SolidQueue::FailedExecution.count
        puts "✓ SolidQueue: #{pending} pending, #{failed} failed jobs"
      else
        puts "⚠ SolidQueue configured but not available"
      end
    when :async
      puts "⚠ Using async adapter - jobs may not execute reliably in development"
    else
      puts "⚠ Unknown queue adapter: #{adapter}"
    end

    # Check for sessions that may have been enqueued but never processed
    potentially_stuck = Session.where(processing_state: "processing")
                               .where("updated_at < ?", 10.minutes.ago)

    if potentially_stuck.any?
      puts "⚠ Found #{potentially_stuck.count} sessions that may be stuck:"
      potentially_stuck.each do |session|
        puts "  Session #{session.id}: processing for #{((Time.current - session.updated_at) / 60).to_i} minutes"
      end
    end
  end

  desc "Fix environment for job processing"
  task fix_job_environment: :environment do
    if Rails.env.development?
      puts "Development environment detected"

      adapter = Rails.application.config.active_job.queue_adapter
      case adapter
      when :inline
        puts "✓ Jobs configured to execute immediately (inline adapter)"
      when :async
        puts "⚠ Found async adapter - this may cause jobs to not execute"
        puts "Consider adding this to config/environments/development.rb:"
        puts "  config.active_job.queue_adapter = :inline"
      else
        puts "⚠ Queue adapter: #{adapter}"
        puts "For development, consider using :inline adapter for immediate execution"
      end
    end
  end
end
