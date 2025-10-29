module Privacy
  class AudioCleanupService
    def self.cleanup_expired_audio
      new.cleanup_expired_audio
    end

    def cleanup_expired_audio
      User.find_each do |user|
        cleanup_user_audio(user)
      end
    end

    private

    def cleanup_user_audio(user)
      return unless user.auto_delete_audio_days

      cutoff_date = user.auto_delete_audio_days.days.ago
      expired_sessions = user.sessions.where("created_at < ?", cutoff_date)

      expired_sessions.find_each do |session|
        cleanup_session_audio(session, user)
      end
    end

    def cleanup_session_audio(session, user)
      return unless session.media_files.attached?

      files_deleted = 0

      session.media_files.each do |file|
        begin
          # Log the deletion for audit purposes
          Rails.logger.info("Privacy cleanup: Deleting audio file #{file.filename} from session #{session.id} for user #{user.email}")

          file.purge
          files_deleted += 1

        rescue => e
          Rails.logger.error("Failed to delete audio file #{file.filename} from session #{session.id}: #{e.message}")
        end
      end

      if files_deleted > 0
        # Update session to indicate audio was removed for privacy
        session.update!(
          analysis_data: session.analysis_data.merge(
            "audio_deleted_for_privacy" => true,
            "audio_deleted_at" => Time.current.iso8601,
            "files_deleted_count" => files_deleted
          )
        )
      end

      files_deleted
    end

    def cleanup_processed_audio_if_enabled(session)
      return unless session.user.delete_processed_audio?
      return unless session.completed?
      return unless session.media_files.attached?

      # Only delete if analysis is complete and we have the essential data
      essential_data = %w[transcript wpm filler_rate clarity_score]
      has_essential_data = essential_data.any? { |key| session.analysis_data[key].present? }

      return unless has_essential_data

      files_deleted = 0

      session.media_files.each do |file|
        begin
          Rails.logger.info("Privacy cleanup: Deleting processed audio file #{file.filename} from completed session #{session.id}")

          file.purge
          files_deleted += 1

        rescue => e
          Rails.logger.error("Failed to delete processed audio file #{file.filename} from session #{session.id}: #{e.message}")
        end
      end

      if files_deleted > 0
        session.update!(
          analysis_data: session.analysis_data.merge(
            "processed_audio_deleted" => true,
            "processed_audio_deleted_at" => Time.current.iso8601,
            "processed_files_deleted_count" => files_deleted
          )
        )
      end

      files_deleted
    end

    def generate_cleanup_report
      report = {
        generated_at: Time.current.iso8601,
        users_processed: 0,
        sessions_processed: 0,
        files_deleted: 0,
        errors: [],
        privacy_stats: {
          users_with_auto_delete: 0,
          users_with_processed_delete: 0,
          average_retention_days: 0
        }
      }

      User.find_each do |user|
        report[:users_processed] += 1

        if user.auto_delete_audio_days
          report[:privacy_stats][:users_with_auto_delete] += 1
        end

        if user.delete_processed_audio?
          report[:privacy_stats][:users_with_processed_delete] += 1
        end

        cutoff_date = (user.auto_delete_audio_days || 365).days.ago
        user_expired_sessions = user.sessions.where("created_at < ?", cutoff_date)
        report[:sessions_processed] += user_expired_sessions.count

        user_expired_sessions.find_each do |session|
          begin
            deleted = cleanup_session_audio(session, user)
            report[:files_deleted] += deleted
          rescue => e
            report[:errors] << {
              session_id: session.id,
              user_email: user.email,
              error: e.message
            }
          end
        end
      end

      # Calculate average retention
      retention_days = User.where.not(auto_delete_audio_days: nil).pluck(:auto_delete_audio_days)
      if retention_days.any?
        report[:privacy_stats][:average_retention_days] = retention_days.sum / retention_days.length
      end

      report
    end
  end
end
