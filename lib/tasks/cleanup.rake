namespace :aitalkcoach do
  desc "Clean up orphaned FFmpeg processes (similar to imagesweep browser cleanup)"
  task cleanup_ffmpeg: :environment do
    puts "Starting FFmpeg process cleanup..."

    begin
      # Find all FFmpeg processes
      ffmpeg_pids = `pgrep -f "ffmpeg"`.split.map(&:to_i)

      if ffmpeg_pids.empty?
        puts "No FFmpeg processes found."
        next
      end

      puts "Found #{ffmpeg_pids.length} FFmpeg processes"

      # Get detailed process information
      cleaned_count = 0
      ffmpeg_pids.each do |pid|
        begin
          # Get process start time to identify long-running processes
          process_info = `ps -o pid,etime,command -p #{pid}`.lines[1]
          next unless process_info

          # Extract elapsed time (simple parsing - format like "05:23" or "1-05:23:45")
          etime = process_info.split[1]

          # Consider processes running longer than 15 minutes as orphaned
          # This is more aggressive than imagesweep's browser timeout
          should_kill = case etime
          when /(\d+)-/  # Days format like "1-05:23:45"
            true  # Any process running for days is definitely orphaned
          when /(\d{2,}):(\d{2}):(\d{2})/  # Hours format like "01:23:45"
            hours = $1.to_i
            hours >= 1  # Kill processes running for 1+ hours
          when /(\d{2,}):(\d{2})/  # Minutes format like "15:23"
            minutes = $1.to_i
            minutes >= 15  # Kill processes running for 15+ minutes
          else
            false  # Keep newer processes
          end

          if should_kill
            puts "Killing long-running FFmpeg process #{pid} (running for #{etime})"
            Process.kill("TERM", pid)
            sleep(2)  # Give it time to terminate gracefully

            # Force kill if still running
            begin
              Process.kill(0, pid)  # Check if process still exists
              puts "Force killing FFmpeg process #{pid}"
              Process.kill("KILL", pid)
            rescue Errno::ESRCH
              # Process already terminated
            end

            cleaned_count += 1
          else
            puts "Keeping recent FFmpeg process #{pid} (running for #{etime})"
          end

        rescue Errno::ESRCH
          # Process already terminated
          puts "FFmpeg process #{pid} already terminated"
        rescue => e
          puts "Error processing FFmpeg process #{pid}: #{e.message}"
        end
      end

      puts "FFmpeg cleanup completed. Cleaned up #{cleaned_count} orphaned processes."

    rescue => e
      puts "Error during FFmpeg cleanup: #{e.message}"
      raise
    end
  end

  desc "Monitor FFmpeg process usage"
  task monitor_ffmpeg: :environment do
    puts "FFmpeg Process Monitor"
    puts "====================="

    begin
      # Get current FFmpeg processes
      ffmpeg_processes = `pgrep -f "ffmpeg" | wc -l`.to_i

      puts "Current FFmpeg processes: #{ffmpeg_processes}"

      if ffmpeg_processes > 0
        puts "\nDetailed process information:"
        puts `ps aux | grep ffmpeg | grep -v grep`
      end

      # Memory usage
      if ffmpeg_processes > 0
        total_memory = `ps -o pid,rss -p $(pgrep -f "ffmpeg" | tr '\n' ',')`.lines[1..-1].map do |line|
          line.split[1].to_i
        end.sum

        memory_mb = total_memory / 1024.0
        puts "\nTotal FFmpeg memory usage: #{memory_mb.round(2)} MB"
      end

      # System health status
      case ffmpeg_processes
      when 0
        puts "\nStatus: HEALTHY - No FFmpeg processes running"
      when 1..3
        puts "\nStatus: NORMAL - #{ffmpeg_processes} processes (expected for active processing)"
      when 4..8
        puts "\nStatus: ELEVATED - #{ffmpeg_processes} processes (monitor closely)"
      when 9..15
        puts "\nStatus: WARNING - #{ffmpeg_processes} processes (may indicate process accumulation)"
      else
        puts "\nStatus: CRITICAL - #{ffmpeg_processes} processes (cleanup recommended)"
      end

    rescue => e
      puts "Error during FFmpeg monitoring: #{e.message}"
      raise
    end
  end

  desc "Full system cleanup (FFmpeg + temp files)"
  task full_cleanup: :environment do
    puts "Starting full system cleanup..."

    # Clean up FFmpeg processes
    Rake::Task["aitalkcoach:cleanup_ffmpeg"].invoke

    # Clean up temporary files
    puts "\nCleaning up temporary audio files..."
    temp_dir = Rails.root.join("tmp")

    begin
      # Find and remove old temporary audio files
      old_files = Dir.glob(temp_dir.join("**", "*.{wav,mp3,mp4,m4a,webm}")).select do |file|
        File.mtime(file) < 1.hour.ago
      end

      old_files.each do |file|
        begin
          File.delete(file)
          puts "Removed old temp file: #{file}"
        rescue => e
          puts "Failed to remove #{file}: #{e.message}"
        end
      end

      puts "Cleaned up #{old_files.length} temporary audio files"

    rescue => e
      puts "Error during temp file cleanup: #{e.message}"
    end

    # Clean up old log files (keep last 7 days)
    puts "\nCleaning up old log files..."
    begin
      log_dir = Rails.root.join("log")
      if log_dir.exist?
        old_logs = Dir.glob(log_dir.join("*.log.*")).select do |file|
          File.mtime(file) < 7.days.ago
        end

        old_logs.each do |file|
          begin
            File.delete(file)
            puts "Removed old log file: #{file}"
          rescue => e
            puts "Failed to remove #{file}: #{e.message}"
          end
        end

        puts "Cleaned up #{old_logs.length} old log files"
      end
    rescue => e
      puts "Error during log cleanup: #{e.message}"
    end

    puts "\nFull cleanup completed!"
  end

  desc "Emergency FFmpeg cleanup (force kill all FFmpeg processes)"
  task emergency_cleanup: :environment do
    puts "EMERGENCY CLEANUP: Force killing all FFmpeg processes"
    puts "Warning: This will terminate all FFmpeg processes immediately!"

    begin
      # Get all FFmpeg processes
      ffmpeg_pids = `pgrep -f "ffmpeg"`.split.map(&:to_i)

      if ffmpeg_pids.empty?
        puts "No FFmpeg processes found."
        next
      end

      puts "Found #{ffmpeg_pids.length} FFmpeg processes to terminate"

      # Force kill all processes
      system("pkill -9 -f ffmpeg")

      # Verify cleanup
      sleep(2)
      remaining_processes = `pgrep -f "ffmpeg" | wc -l`.to_i

      if remaining_processes == 0
        puts "Emergency cleanup successful - all FFmpeg processes terminated"
      else
        puts "Warning: #{remaining_processes} FFmpeg processes still running"
      end

    rescue => e
      puts "Error during emergency cleanup: #{e.message}"
      raise
    end
  end
end
