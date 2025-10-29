module Billing
  class RetryChargeJob < ApplicationJob
    queue_as :default

    # Retry with exponential backoff if job itself fails
    retry_on StandardError, wait: :exponentially_longer, attempts: 3

    def perform(user_id)
      user = User.find(user_id)

      # Only retry if subscription is still past_due
      unless user.subscription_status == "past_due"
        Rails.logger.info "Skipping retry for user #{user_id}: subscription status is #{user.subscription_status}"
        return
      end

      Rails.logger.info "Retrying payment for user #{user_id} (attempt #{user.payment_retry_count}/#{Billing::ChargeUser::MAX_RETRY_ATTEMPTS})"

      result = Billing::ChargeUser.call(user)

      if result
        # Payment succeeded - reset retry count
        user.update(payment_retry_count: 0)
        Rails.logger.info "Retry successful for user #{user_id}, subscription reactivated"
      else
        Rails.logger.warn "Retry failed for user #{user_id}"
      end
    end
  end
end
