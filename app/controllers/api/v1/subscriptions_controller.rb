module Api
  module V1
    class SubscriptionsController < ApplicationController
      before_action :require_login

      # GET /api/v1/subscriptions/status
      # Check current user's subscription status across all platforms
      def status
        render json: {
          success: true,
          subscription: {
            can_access_app: current_user.can_access_app?,
            status: current_user.subscription_status,
            platform: current_user.subscription_platform,
            plan: current_user.subscription_plan,
            trial_active: current_user.trial_active?,
            trial_expires_at: current_user.trial_expires_at,
            current_period_end: current_user.current_period_end,
            # Stripe details
            stripe_customer_id: current_user.stripe_customer_id,
            stripe_subscription_id: current_user.stripe_subscription_id,
            # Apple details
            apple_subscription_id: current_user.apple_subscription_id,
            revenuecat_customer_id: current_user.revenuecat_customer_id,
          }
        }
      end

      # POST /api/v1/subscriptions/sync
      # Sync RevenueCat subscription to user account
      # Called after successful purchase in mobile app
      def sync
        revenuecat_customer_id = params[:revenuecat_customer_id]
        apple_subscription_id = params[:apple_subscription_id]
        subscription_status = params[:subscription_status] # active, cancelled, expired
        expires_date = params[:expires_date]
        product_id = params[:product_id] # "02" or "03"

        if revenuecat_customer_id.blank?
          return render json: {
            success: false,
            error: "revenuecat_customer_id is required"
          }, status: :bad_request
        end

        begin
          # Determine subscription plan from product ID
          plan = case product_id
          when "02"
            "monthly"
          when "03"
            "yearly"
          else
            "monthly" # default
          end

          # Update user with Apple subscription details
          current_user.update!(
            revenuecat_customer_id: revenuecat_customer_id,
            apple_subscription_id: apple_subscription_id,
            subscription_platform: "apple",
            subscription_status: subscription_status || "active",
            subscription_plan: plan,
            current_period_end: expires_date ? Time.parse(expires_date) : nil
          )

          Rails.logger.info "Synced Apple subscription for user #{current_user.id}: #{revenuecat_customer_id}"

          render json: {
            success: true,
            message: "Subscription synced successfully",
            subscription: {
              can_access_app: current_user.can_access_app?,
              status: current_user.subscription_status,
              platform: current_user.subscription_platform,
              plan: current_user.subscription_plan,
            }
          }
        rescue StandardError => e
          Rails.logger.error "Error syncing subscription: #{e.message}"
          Sentry.capture_exception(e) if defined?(Sentry)

          render json: {
            success: false,
            error: "Failed to sync subscription"
          }, status: :internal_server_error
        end
      end

      # POST /api/v1/subscriptions/restore
      # Handle restore purchases
      # Updates user account with restored subscription details
      def restore
        revenuecat_customer_id = params[:revenuecat_customer_id]
        has_active_subscription = params[:has_active_subscription]

        if revenuecat_customer_id.blank?
          return render json: {
            success: false,
            error: "revenuecat_customer_id is required"
          }, status: :bad_request
        end

        begin
          # Check if subscription is active
          if has_active_subscription
            # Find subscription details from params
            apple_subscription_id = params[:apple_subscription_id]
            product_id = params[:product_id]
            expires_date = params[:expires_date]

            plan = case product_id
            when "02"
              "monthly"
            when "03"
              "yearly"
            else
              "monthly"
            end

            current_user.update!(
              revenuecat_customer_id: revenuecat_customer_id,
              apple_subscription_id: apple_subscription_id,
              subscription_platform: "apple",
              subscription_status: "active",
              subscription_plan: plan,
              current_period_end: expires_date ? Time.parse(expires_date) : nil
            )

            Rails.logger.info "Restored Apple subscription for user #{current_user.id}"

            render json: {
              success: true,
              message: "Subscription restored successfully",
              has_active_subscription: true,
              subscription: {
                can_access_app: current_user.can_access_app?,
                status: current_user.subscription_status,
                platform: current_user.subscription_platform,
                plan: current_user.subscription_plan,
              }
            }
          else
            # No active subscription to restore
            render json: {
              success: true,
              message: "No active subscription found",
              has_active_subscription: false
            }
          end
        rescue StandardError => e
          Rails.logger.error "Error restoring subscription: #{e.message}"
          Sentry.capture_exception(e) if defined?(Sentry)

          render json: {
            success: false,
            error: "Failed to restore subscription"
          }, status: :internal_server_error
        end
      end
    end
  end
end
