module Maintenance
  class StorageAnalyzer
    class << self
      def generate_report
        new.generate_report
      end
    end
    
    def generate_report
      Rails.logger.info "Generating storage usage report"
      
      report = {
        generated_at: Time.current.iso8601,
        session_stats: analyze_session_statistics,
        media_stats: analyze_media_file_statistics,
        storage_by_age: analyze_storage_by_age,
        storage_by_user: analyze_storage_by_user,
        cleanup_opportunities: identify_cleanup_opportunities,
        system_storage: analyze_system_storage,
        errors: []
      }
      
      Rails.logger.info "Storage analysis completed"
      report
    rescue StandardError => e
      Rails.logger.error "Storage analysis failed: #{e.message}"
      {
        generated_at: Time.current.iso8601,
        error: "Analysis failed: #{e.message}",
        errors: [e.message]
      }
    end
    
    private
    
    def analyze_session_statistics
      {
        total_sessions: Session.count,
        sessions_with_media: Session.joins(:media_files_attachments).distinct.count,
        completed_sessions: Session.completed.count,
        failed_sessions: Session.where(processing_state: 'failed').count,
        sessions_last_30_days: Session.where(created_at: 30.days.ago..Time.current).count
      }
    end
    
    def analyze_media_file_statistics
      media_blobs = ActiveStorage::Blob
                     .joins(:attachments)
                     .where(active_storage_attachments: { name: 'media_files' })
      
      total_files = media_blobs.count
      total_size = media_blobs.sum(:byte_size)
      average_size = total_files > 0 ? total_size / total_files : 0
      
      {
        total_files: total_files,
        total_size: total_size,
        total_size_formatted: format_bytes(total_size),
        average_file_size: average_size,
        average_file_size_formatted: format_bytes(average_size),
        largest_file_size: media_blobs.maximum(:byte_size) || 0,
        smallest_file_size: media_blobs.minimum(:byte_size) || 0
      }
    end
    
    def analyze_storage_by_age
      age_groups = {
        '0-7 days' => 7.days.ago..Time.current,
        '8-30 days' => 30.days.ago..7.days.ago,
        '31-90 days' => 90.days.ago..30.days.ago,
        '91+ days' => Time.at(0)..90.days.ago
      }
      
      storage_by_age = {}
      
      age_groups.each do |label, date_range|
        sessions_in_range = Session.joins(:media_files_attachments)
                                  .where(created_at: date_range)
                                  .distinct
        
        media_blobs = ActiveStorage::Blob
                       .joins(:attachments)
                       .joins("JOIN sessions ON active_storage_attachments.record_id = sessions.id")
                       .where(active_storage_attachments: { name: 'media_files', record_type: 'Session' })
                       .where(sessions: { created_at: date_range })
        
        total_size = media_blobs.sum(:byte_size)
        file_count = media_blobs.count
        
        storage_by_age[label] = {
          sessions: sessions_in_range.count,
          count: file_count,
          size: total_size,
          size_formatted: format_bytes(total_size)
        }
      end
      
      storage_by_age
    end
    
    def analyze_storage_by_user
      user_storage_stats = []
      
      User.includes(:sessions).find_each do |user|
        user_sessions = user.sessions.joins(:media_files_attachments).distinct
        next if user_sessions.empty?
        
        user_blobs = ActiveStorage::Blob
                      .joins(:attachments)
                      .joins("JOIN sessions ON active_storage_attachments.record_id = sessions.id")
                      .where(active_storage_attachments: { name: 'media_files', record_type: 'Session' })
                      .where(sessions: { user_id: user.id })
        
        total_size = user_blobs.sum(:byte_size)
        file_count = user_blobs.count
        
        user_storage_stats << {
          user_id: user.id,
          user_email: user.email || "user_#{user.id}",
          sessions_count: user_sessions.count,
          files_count: file_count,
          total_size: total_size,
          total_size_formatted: format_bytes(total_size),
          average_session_size: user_sessions.count > 0 ? total_size / user_sessions.count : 0,
          oldest_session: user_sessions.minimum(:created_at)&.iso8601,
          newest_session: user_sessions.maximum(:created_at)&.iso8601,
          auto_delete_days: user.respond_to?(:auto_delete_audio_days) ? user.auto_delete_audio_days : nil
        }
      end
      
      # Sort by total size descending and return top 20
      user_storage_stats.sort_by { |stats| -stats[:total_size] }.first(20)
    end
    
    def identify_cleanup_opportunities
      opportunities = []
      
      # Expired audio based on default retention
      default_retention = (ENV['DEFAULT_AUDIO_RETENTION_DAYS'] || '90').to_i.days
      expired_sessions = Session.joins(:media_files_attachments)
                               .where('sessions.created_at < ?', default_retention.ago)
                               .distinct
      
      if expired_sessions.any?
        expired_blobs = ActiveStorage::Blob
                         .joins(:attachments)
                         .joins("JOIN sessions ON active_storage_attachments.record_id = sessions.id")
                         .where(active_storage_attachments: { name: 'media_files', record_type: 'Session' })
                         .where(sessions: { id: expired_sessions.pluck(:id) })
        
        expired_size = expired_blobs.sum(:byte_size)
        expired_count = expired_blobs.count
        
        opportunities << {
          type: 'Expired audio files',
          count: expired_count,
          size: expired_size,
          size_formatted: format_bytes(expired_size),
          sessions_affected: expired_sessions.count,
          description: "Files older than #{default_retention.to_i} days"
        }
      end
      
      # Orphaned attachments
      orphaned_blobs = ActiveStorage::Blob
                        .left_joins(:attachments)
                        .where(active_storage_attachments: { id: nil })
                        .where('active_storage_blobs.created_at < ?', 7.days.ago)
      
      if orphaned_blobs.any?
        orphaned_size = orphaned_blobs.sum(:byte_size)
        orphaned_count = orphaned_blobs.count
        
        opportunities << {
          type: 'Orphaned attachments',
          count: orphaned_count,
          size: orphaned_size,
          size_formatted: format_bytes(orphaned_size),
          description: "Blobs not referenced by any attachment"
        }
      end
      
      # Failed sessions with media
      failed_sessions = Session.where(processing_state: 'failed')
                              .joins(:media_files_attachments)
                              .where('sessions.created_at < ?', 7.days.ago)
                              .distinct
      
      if failed_sessions.any?
        failed_blobs = ActiveStorage::Blob
                        .joins(:attachments)
                        .joins("JOIN sessions ON active_storage_attachments.record_id = sessions.id")
                        .where(active_storage_attachments: { name: 'media_files', record_type: 'Session' })
                        .where(sessions: { id: failed_sessions.pluck(:id) })
        
        failed_size = failed_blobs.sum(:byte_size)
        failed_count = failed_blobs.count
        
        opportunities << {
          type: 'Failed session media',
          count: failed_count,
          size: failed_size,
          size_formatted: format_bytes(failed_size),
          sessions_affected: failed_sessions.count,
          description: "Media from failed processing sessions older than 7 days"
        }
      end
      
      # Large files that might benefit from compression
      large_files = ActiveStorage::Blob
                     .joins(:attachments)
                     .where(active_storage_attachments: { name: 'media_files' })
                     .where('byte_size > ?', 50.megabytes)
      
      if large_files.any?
        large_files_size = large_files.sum(:byte_size)
        large_files_count = large_files.count
        
        opportunities << {
          type: 'Large files (>50MB)',
          count: large_files_count,
          size: large_files_size,
          size_formatted: format_bytes(large_files_size),
          description: "Files that might benefit from compression or format optimization"
        }
      end
      
      opportunities
    end
    
    def analyze_system_storage
      return { error: 'System storage analysis not available' } unless system_storage_available?
      
      begin
        df_output = `df #{Rails.root} | tail -1`.split
        
        {
          filesystem: df_output[0],
          total_blocks: df_output[1].to_i,
          used_blocks: df_output[2].to_i,
          available_blocks: df_output[3].to_i,
          usage_percentage: df_output[4].to_i,
          mount_point: df_output[5],
          total_size_formatted: format_bytes(df_output[1].to_i * 1024),
          used_size_formatted: format_bytes(df_output[2].to_i * 1024),
          available_size_formatted: format_bytes(df_output[3].to_i * 1024),
          status: determine_storage_status(df_output[4].to_i)
        }
      rescue StandardError => e
        { error: "Failed to analyze system storage: #{e.message}" }
      end
    end
    
    def system_storage_available?
      # Check if we're on a Unix-like system with df command
      system('which df > /dev/null 2>&1')
    end
    
    def determine_storage_status(usage_percentage)
      case usage_percentage
      when 0..70
        :healthy
      when 71..85
        :warning
      when 86..95
        :critical
      else
        :emergency
      end
    end
    
    def format_bytes(bytes)
      return '0 B' if bytes.zero?
      
      units = %w[B KB MB GB TB PB]
      size = bytes.to_f
      unit_index = 0
      
      while size >= 1024 && unit_index < units.length - 1
        size /= 1024.0
        unit_index += 1
      end
      
      "#{size.round(2)} #{units[unit_index]}"
    end
  end
end