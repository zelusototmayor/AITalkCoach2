module Maintenance
  class FileCleanupJob < ApplicationJob
    queue_as :maintenance
    
    # Custom error classes for cleanup operations
    class CleanupError < StandardError; end
    class StorageError < CleanupError; end
    
    def perform(cleanup_type: :all, options: {})
      @options = options.with_indifferent_access
      @cleanup_stats = initialize_cleanup_stats
      
      Rails.logger.info "Starting file cleanup job: #{cleanup_type}"
      
      case cleanup_type
      when :expired_audio
        cleanup_expired_audio_files
      when :temporary_files
        cleanup_temporary_files
      when :orphaned_attachments
        cleanup_orphaned_attachments
      when :processed_media
        cleanup_processed_media_files
      when :cache_files
        cleanup_cache_files
      when :logs
        cleanup_old_logs
      when :all
        run_comprehensive_cleanup
      else
        raise ArgumentError, "Unknown cleanup type: #{cleanup_type}"
      end
      
      # Generate and log cleanup report
      generate_cleanup_report
      
      Rails.logger.info "File cleanup job completed successfully"
      
    rescue StandardError => e
      handle_cleanup_error(e)
      raise
    end
    
    private
    
    def initialize_cleanup_stats
      {
        started_at: Time.current,
        files_deleted: 0,
        bytes_freed: 0,
        errors: [],
        operations: []
      }
    end
    
    def run_comprehensive_cleanup
      operations = [
        :expired_audio,
        :temporary_files,
        :orphaned_attachments,
        :processed_media,
        :cache_files
      ]
      
      # Add log cleanup if not in development
      operations << :logs unless Rails.env.development?
      
      operations.each do |operation|
        begin
          Rails.logger.info "Running cleanup operation: #{operation}"
          send("cleanup_#{operation}_files")
          @cleanup_stats[:operations] << { operation: operation, status: :completed }
        rescue StandardError => e
          Rails.logger.error "Cleanup operation #{operation} failed: #{e.message}"
          @cleanup_stats[:errors] << {
            operation: operation,
            error: e.class.name,
            message: e.message
          }
          @cleanup_stats[:operations] << { operation: operation, status: :failed }
          
          # Report to monitoring but continue with other operations
          Monitoring::ErrorReporter.report_job_error(self, e, {
            cleanup_operation: operation,
            cleanup_type: :comprehensive
          })
        end
      end
    end
    
    def cleanup_expired_audio_files
      Rails.logger.info "Starting expired audio file cleanup"
      
      files_deleted = 0
      bytes_freed = 0
      
      # Use the existing Privacy::AudioCleanupService
      cleanup_service = Privacy::AudioCleanupService.new
      
      User.includes(:sessions).find_each do |user|
        next unless should_cleanup_user_audio?(user)
        
        cutoff_date = (user.auto_delete_audio_days || default_retention_days).days.ago
        expired_sessions = user.sessions
                              .joins(:media_files_attachments)
                              .where('sessions.created_at < ?', cutoff_date)
        
        expired_sessions.find_each do |session|
          session_files_deleted, session_bytes_freed = cleanup_session_files(session, :audio_expired)
          files_deleted += session_files_deleted
          bytes_freed += session_bytes_freed
        end
      end
      
      update_cleanup_stats(:expired_audio, files_deleted, bytes_freed)
    end
    
    def cleanup_temporary_files
      Rails.logger.info "Starting temporary file cleanup"
      
      temp_directories = [
        Rails.root.join('tmp', 'audio_processing'),
        Rails.root.join('tmp', 'extractions'),
        Rails.root.join('storage', 'tmp')
      ]
      
      files_deleted = 0
      bytes_freed = 0
      
      temp_directories.each do |temp_dir|
        next unless temp_dir.exist?
        
        cutoff_time = 24.hours.ago
        
        temp_dir.glob('**/*').select(&:file?).each do |file|
          next unless file.mtime < cutoff_time
          
          begin
            file_size = file.size
            file.delete
            
            files_deleted += 1
            bytes_freed += file_size
            
            Rails.logger.debug "Deleted temporary file: #{file}"
            
          rescue Errno::ENOENT
            # File already deleted, ignore
          rescue StandardError => e
            Rails.logger.warn "Failed to delete temporary file #{file}: #{e.message}"
            @cleanup_stats[:errors] << {
              operation: :temporary_files,
              file: file.to_s,
              error: e.message
            }
          end
        end
      end
      
      update_cleanup_stats(:temporary_files, files_deleted, bytes_freed)
    end
    
    def cleanup_orphaned_attachments
      Rails.logger.info "Starting orphaned attachment cleanup"
      
      files_deleted = 0
      bytes_freed = 0
      
      # Find ActiveStorage blobs that are not referenced by any attachment
      orphaned_blobs = ActiveStorage::Blob
                        .left_joins(:attachments)
                        .where(active_storage_attachments: { id: nil })
                        .where('active_storage_blobs.created_at < ?', 7.days.ago)
      
      orphaned_blobs.find_each do |blob|
        begin
          file_size = blob.byte_size
          blob.purge
          
          files_deleted += 1
          bytes_freed += file_size
          
          Rails.logger.debug "Deleted orphaned blob: #{blob.key}"
          
        rescue StandardError => e
          Rails.logger.warn "Failed to delete orphaned blob #{blob.key}: #{e.message}"
          @cleanup_stats[:errors] << {
            operation: :orphaned_attachments,
            blob_key: blob.key,
            error: e.message
          }
        end
      end
      
      update_cleanup_stats(:orphaned_attachments, files_deleted, bytes_freed)
    end
    
    def cleanup_processed_media_files
      Rails.logger.info "Starting processed media file cleanup"
      
      files_deleted = 0
      bytes_freed = 0
      
      # Find sessions that are completed and have been processed for a certain time
      cutoff_date = (ENV['PROCESSED_MEDIA_RETENTION_DAYS'] || '30').to_i.days.ago
      
      processed_sessions = Session.completed
                                 .where('processed_at < ?', cutoff_date)
                                 .joins(:media_files_attachments)
      
      processed_sessions.find_each do |session|
        # Only delete if we have essential analysis data preserved
        next unless session_has_essential_data?(session)
        next unless user_allows_processed_deletion?(session.user)
        
        session_files_deleted, session_bytes_freed = cleanup_session_files(session, :processed_retention)
        files_deleted += session_files_deleted
        bytes_freed += session_bytes_freed
      end
      
      update_cleanup_stats(:processed_media, files_deleted, bytes_freed)
    end
    
    def cleanup_cache_files
      Rails.logger.info "Starting cache file cleanup"
      
      files_deleted = 0
      bytes_freed = 0
      
      # Clean up Solid Cache files if using file-based cache
      if Rails.cache.is_a?(ActiveSupport::Cache::SolidCacheStore)
        cache_cleanup_result = cleanup_solid_cache_files
        files_deleted += cache_cleanup_result[:files_deleted]
        bytes_freed += cache_cleanup_result[:bytes_freed]
      end
      
      # Clean up AI response cache files
      ai_cache_cleanup_result = cleanup_ai_cache_files
      files_deleted += ai_cache_cleanup_result[:files_deleted]
      bytes_freed += ai_cache_cleanup_result[:bytes_freed]
      
      update_cleanup_stats(:cache_files, files_deleted, bytes_freed)
    end
    
    def cleanup_old_logs
      Rails.logger.info "Starting old log cleanup"
      
      return if Rails.env.development?
      
      files_deleted = 0
      bytes_freed = 0
      
      log_retention_days = (ENV['LOG_RETENTION_DAYS'] || '90').to_i
      cutoff_date = log_retention_days.days.ago
      
      log_files = Dir.glob(Rails.root.join('log', '*.log.*'))
      
      log_files.each do |log_file|
        file_path = Pathname.new(log_file)
        next unless file_path.exist?
        next unless file_path.mtime < cutoff_date
        
        begin
          file_size = file_path.size
          file_path.delete
          
          files_deleted += 1
          bytes_freed += file_size
          
          Rails.logger.debug "Deleted old log file: #{log_file}"
          
        rescue StandardError => e
          Rails.logger.warn "Failed to delete log file #{log_file}: #{e.message}"
          @cleanup_stats[:errors] << {
            operation: :logs,
            file: log_file,
            error: e.message
          }
        end
      end
      
      update_cleanup_stats(:logs, files_deleted, bytes_freed)
    end
    
    def cleanup_session_files(session, cleanup_reason)
      files_deleted = 0
      bytes_freed = 0
      
      session.media_files.each do |file|
        begin
          file_size = file.blob.byte_size
          file.purge
          
          files_deleted += 1
          bytes_freed += file_size
          
          Rails.logger.debug "Deleted media file from session #{session.id}: #{file.filename}"
          
        rescue StandardError => e
          Rails.logger.warn "Failed to delete media file from session #{session.id}: #{e.message}"
          @cleanup_stats[:errors] << {
            operation: cleanup_reason,
            session_id: session.id,
            file: file.filename.to_s,
            error: e.message
          }
        end
      end
      
      # Update session to record cleanup
      if files_deleted > 0
        update_session_cleanup_metadata(session, cleanup_reason, files_deleted, bytes_freed)
      end
      
      [files_deleted, bytes_freed]
    end
    
    def cleanup_solid_cache_files
      # This would depend on how SolidCache stores its files
      # For now, return zero counts
      { files_deleted: 0, bytes_freed: 0 }
    end
    
    def cleanup_ai_cache_files
      files_deleted = 0
      bytes_freed = 0
      
      # Clean up expired AI cache entries
      cache_retention_days = (ENV['AI_CACHE_RETENTION_DAYS'] || '14').to_i
      cutoff_date = cache_retention_days.days.ago
      
      expired_cache_entries = AiCache.where('created_at < ?', cutoff_date)
      
      expired_cache_entries.find_each do |cache_entry|
        begin
          # Estimate the storage size (rough approximation)
          estimated_size = cache_entry.response_data.to_s.bytesize
          cache_entry.destroy
          
          files_deleted += 1
          bytes_freed += estimated_size
          
        rescue StandardError => e
          Rails.logger.warn "Failed to delete AI cache entry #{cache_entry.id}: #{e.message}"
          @cleanup_stats[:errors] << {
            operation: :ai_cache,
            cache_entry_id: cache_entry.id,
            error: e.message
          }
        end
      end
      
      { files_deleted: files_deleted, bytes_freed: bytes_freed }
    end
    
    def should_cleanup_user_audio?(user)
      return false unless user.auto_delete_audio_days.present?
      return false if @options[:user_ids].present? && !@options[:user_ids].include?(user.id)
      
      true
    end
    
    def session_has_essential_data?(session)
      essential_keys = %w[transcript wpm filler_rate clarity_score]
      essential_keys.any? { |key| session.analysis_data[key].present? }
    end
    
    def user_allows_processed_deletion?(user)
      # Check if user has opted into processed file deletion
      user.respond_to?(:delete_processed_audio?) ? user.delete_processed_audio? : false
    end
    
    def default_retention_days
      (ENV['DEFAULT_AUDIO_RETENTION_DAYS'] || '90').to_i
    end
    
    def update_session_cleanup_metadata(session, cleanup_reason, files_deleted, bytes_freed)
      cleanup_metadata = {
        "files_deleted_for_#{cleanup_reason}" => true,
        "#{cleanup_reason}_cleanup_at" => Time.current.iso8601,
        "#{cleanup_reason}_files_deleted" => files_deleted,
        "#{cleanup_reason}_bytes_freed" => bytes_freed
      }
      
      session.update!(
        analysis_data: session.analysis_data.merge(cleanup_metadata)
      )
    rescue StandardError => e
      Rails.logger.warn "Failed to update cleanup metadata for session #{session.id}: #{e.message}"
    end
    
    def update_cleanup_stats(operation, files_deleted, bytes_freed)
      @cleanup_stats[:files_deleted] += files_deleted
      @cleanup_stats[:bytes_freed] += bytes_freed
      
      Rails.logger.info "#{operation} cleanup completed: #{files_deleted} files, #{format_bytes(bytes_freed)} freed"
    end
    
    def format_bytes(bytes)
      units = %w[B KB MB GB TB]
      size = bytes.to_f
      unit_index = 0
      
      while size >= 1024 && unit_index < units.length - 1
        size /= 1024.0
        unit_index += 1
      end
      
      "#{size.round(2)} #{units[unit_index]}"
    end
    
    def generate_cleanup_report
      duration = Time.current - @cleanup_stats[:started_at]
      
      report = {
        job_id: job_id,
        started_at: @cleanup_stats[:started_at].iso8601,
        completed_at: Time.current.iso8601,
        duration_seconds: duration.round(2),
        files_deleted: @cleanup_stats[:files_deleted],
        bytes_freed: @cleanup_stats[:bytes_freed],
        bytes_freed_formatted: format_bytes(@cleanup_stats[:bytes_freed]),
        operations: @cleanup_stats[:operations],
        errors: @cleanup_stats[:errors],
        success_rate: calculate_success_rate
      }
      
      Rails.logger.info "Cleanup Report: #{report.to_json}"
      
      # Store report for monitoring/dashboard access
      Rails.cache.write("file_cleanup_report:#{Date.current}", report, expires_in: 30.days)
      
      report
    end
    
    def calculate_success_rate
      return 100.0 if @cleanup_stats[:operations].empty?
      
      successful_ops = @cleanup_stats[:operations].count { |op| op[:status] == :completed }
      total_ops = @cleanup_stats[:operations].count
      
      (successful_ops.to_f / total_ops * 100).round(1)
    end
    
    def handle_cleanup_error(error)
      error_context = {
        job_id: job_id,
        cleanup_stats: @cleanup_stats,
        options: @options
      }
      
      Rails.logger.error "File cleanup job failed: #{error.class.name} - #{error.message}"
      Rails.logger.error error.backtrace&.first(10)&.join("\n")
      
      Monitoring::ErrorReporter.report_job_error(self, error, error_context)
    end
  end
end