class WebhooksController < ApplicationController
  # Skip CSRF protection for webhook endpoint
  skip_before_action :verify_authenticity_token, only: [ :stripe ]

  def stripe
    payload = request.body.read
    sig_header = request.env["HTTP_STRIPE_SIGNATURE"]
    webhook_secret = Rails.configuration.stripe[:webhook_secret]

    # Verify webhook signature
    begin
      event = ::Stripe::Webhook.construct_event(
        payload, sig_header, webhook_secret
      )
    rescue JSON::ParserError => e
      Rails.logger.error "Stripe webhook: Invalid payload - #{e.message}"
      head :bad_request and return
    rescue ::Stripe::SignatureVerificationError => e
      Rails.logger.error "Stripe webhook: Invalid signature - #{e.message}"
      head :bad_request and return
    end

    # Process the event
    handler = Billing::WebhookHandler.new(event)
    if handler.process
      head :ok
    else
      head :unprocessable_entity
    end
  end
end
