class TrialSessionCleanupJob < ApplicationJob
  queue_as :maintenance

  def perform
    Rails.logger.info "Starting trial session cleanup"

    # Delete expired trial sessions (24+ hours old)
    deleted_count = TrialSession.expired.destroy_all.count

    Rails.logger.info "Cleaned up #{deleted_count} expired trial sessions"

    deleted_count
  end
end
