module Billing
  class ChargeExpiredTrialsJob < ApplicationJob
    queue_as :default

    def perform
      Rails.logger.info "Starting hourly billing check at #{Time.current}"

      users_to_charge = User.where("trial_expires_at < ?", Time.current)
                            .where(subscription_status: "free_trial")
                            .where.not(onboarding_completed_at: nil)
                            .where.not(stripe_payment_method_id: nil)

      Rails.logger.info "Found #{users_to_charge.count} users with expired trials"

      success_count = 0
      failure_count = 0

      users_to_charge.find_each do |user|
        Rails.logger.info "Processing user #{user.id} (#{user.email}), trial expired: #{user.trial_expires_at}"

        begin
          if Billing::ChargeUser.call(user)
            success_count += 1
            Rails.logger.info "Successfully charged user #{user.id}"
          else
            failure_count += 1
            Rails.logger.warn "Failed to charge user #{user.id}"
          end
        rescue StandardError => e
          failure_count += 1
          Rails.logger.error "Error charging user #{user.id}: #{e.message}"
          Sentry.capture_exception(e) if defined?(Sentry)
        end
      end

      Rails.logger.info "Hourly billing completed: #{success_count} charged, #{failure_count} failed"
    end
  end
end
