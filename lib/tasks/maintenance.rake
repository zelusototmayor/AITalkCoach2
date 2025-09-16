namespace :maintenance do
  desc "Run file cleanup operations"
  task cleanup: :environment do
    puts "Starting file cleanup maintenance task..."
    
    cleanup_type = ENV['CLEANUP_TYPE'] || 'all'
    options = {
      user_ids: ENV['USER_IDS']&.split(',')&.map(&:to_i),
      dry_run: ENV['DRY_RUN'] == 'true'
    }.compact
    
    begin
      Maintenance::FileCleanupJob.perform_now(cleanup_type: cleanup_type, options: options)
      puts "File cleanup completed successfully"
    rescue StandardError => e
      puts "File cleanup failed: #{e.message}"
      raise e
    end
  end
  
  desc "Schedule recurring file cleanup jobs"
  task schedule_cleanup: :environment do
    puts "Scheduling recurring file cleanup jobs..."
    
    # Schedule different cleanup operations at different intervals
    schedules = [
      {
        job: -> { Maintenance::FileCleanupJob.set(queue: :maintenance).perform_later(cleanup_type: :expired_audio) },
        interval: 1.day,
        name: 'Daily expired audio cleanup'
      },
      {
        job: -> { Maintenance::FileCleanupJob.set(queue: :maintenance).perform_later(cleanup_type: :temporary_files) },
        interval: 6.hours,
        name: 'Temporary files cleanup (every 6 hours)'
      },
      {
        job: -> { Maintenance::FileCleanupJob.set(queue: :maintenance).perform_later(cleanup_type: :orphaned_attachments) },
        interval: 1.week,
        name: 'Weekly orphaned attachments cleanup'
      },
      {
        job: -> { Maintenance::FileCleanupJob.set(queue: :maintenance).perform_later(cleanup_type: :cache_files) },
        interval: 3.days,
        name: 'Cache files cleanup (every 3 days)'
      },
      {
        job: -> { Maintenance::FileCleanupJob.set(queue: :maintenance).perform_later(cleanup_type: :logs) },
        interval: 1.week,
        name: 'Weekly log files cleanup'
      }
    ]
    
    schedules.each do |schedule|
      puts "Scheduling: #{schedule[:name]}"
      schedule[:job].call
      puts "  -> Enqueued for #{schedule[:interval]} from now"
    end
    
    puts "All cleanup jobs scheduled successfully"
  end
  
  desc "Generate file storage usage report"
  task storage_report: :environment do
    puts "Generating storage usage report..."
    
    report = Maintenance::StorageAnalyzer.generate_report
    
    puts "\n" + "="*80
    puts "STORAGE USAGE REPORT"
    puts "="*80
    puts "Generated at: #{report[:generated_at]}"
    puts "Total sessions: #{report[:session_stats][:total_sessions]}"
    puts "Sessions with media: #{report[:session_stats][:sessions_with_media]}"
    puts "Total media files: #{report[:media_stats][:total_files]}"
    puts "Total storage used: #{report[:media_stats][:total_size_formatted]}"
    puts "Average file size: #{report[:media_stats][:average_file_size_formatted]}"
    
    puts "\nStorage by age:"
    report[:storage_by_age].each do |age_group, stats|
      puts "  #{age_group}: #{stats[:count]} files, #{stats[:size_formatted]}"
    end
    
    puts "\nCleanup opportunities:"
    report[:cleanup_opportunities].each do |opportunity|
      puts "  #{opportunity[:type]}: #{opportunity[:count]} files, #{opportunity[:size_formatted]} can be freed"
    end
    
    if report[:errors].any?
      puts "\nErrors encountered:"
      report[:errors].each do |error|
        puts "  - #{error}"
      end
    end
    
    puts "="*80
  end
  
  desc "Health check for storage and cleanup systems"
  task health_check: :environment do
    puts "Running maintenance health check..."
    
    health_status = {
      storage_health: check_storage_health,
      queue_health: check_maintenance_queue_health,
      cleanup_job_health: check_cleanup_job_health,
      permissions: check_file_permissions
    }
    
    puts "\n" + "="*60
    puts "MAINTENANCE HEALTH CHECK REPORT"
    puts "="*60
    
    overall_status = health_status.values.all? { |status| status[:healthy] } ? "HEALTHY" : "NEEDS ATTENTION"
    puts "Overall Status: #{overall_status}"
    puts
    
    health_status.each do |component, status|
      status_icon = status[:healthy] ? "✓" : "✗"
      puts "#{status_icon} #{component.to_s.humanize}: #{status[:message]}"
      
      if status[:details]
        status[:details].each do |detail|
          puts "    - #{detail}"
        end
      end
      puts
    end
    
    puts "="*60
    
    exit(1) unless health_status.values.all? { |status| status[:healthy] }
  end
  
  private
  
  def check_storage_health
    begin
      disk_usage = `df #{Rails.root} | tail -1`.split
      usage_percentage = disk_usage[4].to_i
      
      if usage_percentage > 90
        {
          healthy: false,
          message: "Disk usage critical: #{usage_percentage}%",
          details: ["Available space is critically low", "Immediate cleanup required"]
        }
      elsif usage_percentage > 80
        {
          healthy: true,
          message: "Disk usage high: #{usage_percentage}%",
          details: ["Consider scheduling more frequent cleanups"]
        }
      else
        {
          healthy: true,
          message: "Disk usage normal: #{usage_percentage}%"
        }
      end
    rescue
      {
        healthy: false,
        message: "Unable to check disk usage",
        details: ["Disk usage monitoring not available on this system"]
      }
    end
  end
  
  def check_maintenance_queue_health
    return { healthy: false, message: "SolidQueue not available" } unless defined?(SolidQueue)
    
    pending_jobs = SolidQueue::ReadyExecution.where(queue_name: 'maintenance').count
    failed_jobs = SolidQueue::FailedExecution.joins(:job)
                                           .where(solid_queue_jobs: { queue_name: 'maintenance' })
                                           .where('solid_queue_failed_executions.failed_at > ?', 24.hours.ago)
                                           .count
    
    if failed_jobs > 5
      {
        healthy: false,
        message: "High maintenance job failure rate",
        details: [
          "#{failed_jobs} maintenance jobs failed in the last 24 hours",
          "#{pending_jobs} jobs currently pending"
        ]
      }
    elsif pending_jobs > 50
      {
        healthy: false,
        message: "Maintenance queue backlog",
        details: [
          "#{pending_jobs} maintenance jobs pending",
          "Consider scaling maintenance workers"
        ]
      }
    else
      {
        healthy: true,
        message: "Maintenance queue healthy",
        details: ["#{pending_jobs} pending, #{failed_jobs} failed in 24h"]
      }
    end
  rescue
    {
      healthy: false,
      message: "Unable to check maintenance queue health",
      details: ["Queue monitoring not available"]
    }
  end
  
  def check_cleanup_job_health
    # Check if cleanup jobs have been running regularly
    last_cleanup_report = Rails.cache.read("file_cleanup_report:#{Date.current}") ||
                         Rails.cache.read("file_cleanup_report:#{1.day.ago.to_date}")
    
    if last_cleanup_report.nil?
      {
        healthy: false,
        message: "No recent cleanup activity",
        details: [
          "No cleanup report found for today or yesterday",
          "Cleanup jobs may not be running"
        ]
      }
    elsif last_cleanup_report[:errors].any?
      {
        healthy: false,
        message: "Recent cleanup errors detected",
        details: last_cleanup_report[:errors].map { |e| "#{e[:operation]}: #{e[:error]}" }
      }
    else
      {
        healthy: true,
        message: "Cleanup jobs running successfully",
        details: [
          "Last cleanup: #{last_cleanup_report[:completed_at]}",
          "Files deleted: #{last_cleanup_report[:files_deleted]}",
          "Space freed: #{last_cleanup_report[:bytes_freed_formatted]}"
        ]
      }
    end
  end
  
  def check_file_permissions
    directories_to_check = [
      Rails.root.join('storage'),
      Rails.root.join('tmp'),
      Rails.root.join('log')
    ]
    
    permission_issues = []
    
    directories_to_check.each do |dir|
      next unless dir.exist?
      
      unless dir.writable?
        permission_issues << "#{dir} is not writable"
      end
      
      unless dir.readable?
        permission_issues << "#{dir} is not readable"
      end
    end
    
    if permission_issues.any?
      {
        healthy: false,
        message: "File permission issues detected",
        details: permission_issues
      }
    else
      {
        healthy: true,
        message: "File permissions OK"
      }
    end
  rescue
    {
      healthy: false,
      message: "Unable to check file permissions",
      details: ["Permission check failed"]
    }
  end
end