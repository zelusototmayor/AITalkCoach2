class Api::PromoCodesController < ApplicationController
  # No authentication required - promo code validation is a public Stripe lookup
  # Skip onboarding redirect for this API endpoint
  skip_before_action :require_onboarding

  def validate
    code = params[:code]&.strip&.upcase

    if code.blank?
      render json: { valid: false, error: "Code is required" }, status: :unprocessable_entity
      return
    end

    # Validate with Stripe
    begin
      promotion_code = ::Stripe::PromotionCode.list(
        code: code,
        active: true,
        limit: 1
      ).data.first

      if promotion_code
        coupon = promotion_code.coupon

        # Build discount description
        discount_text = if coupon.percent_off
          "#{coupon.percent_off}% off"
        elsif coupon.amount_off
          "€#{(coupon.amount_off / 100.0).round(2)} off"
        else
          "Discount applied"
        end

        # Add duration information
        if coupon.duration == "once"
          discount_text += " (first payment)"
        elsif coupon.duration == "repeating" && coupon.duration_in_months
          discount_text += " (#{coupon.duration_in_months} months)"
        elsif coupon.duration == "forever"
          discount_text += " (forever)"
        end

        render json: {
          valid: true,
          discount: discount_text,
          code: code
        }
      else
        render json: {
          valid: false,
          error: "Invalid or expired promo code"
        }, status: :unprocessable_entity
      end
    rescue ::Stripe::StripeError => e
      Rails.logger.error("Stripe promo code validation error: #{e.message}")
      render json: {
        valid: false,
        error: "Unable to validate promo code. Please try again."
      }, status: :unprocessable_entity
    end
  end
end
