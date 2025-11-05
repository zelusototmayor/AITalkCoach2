class WebhooksController < ApplicationController
  # Skip CSRF protection for webhook endpoints
  skip_before_action :verify_authenticity_token, only: [ :stripe, :revenuecat ]

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

  def revenuecat
    # Parse the webhook payload
    begin
      event_data = JSON.parse(request.body.read)
    rescue JSON::ParserError => e
      Rails.logger.error "RevenueCat webhook: Invalid payload - #{e.message}"
      head :bad_request and return
    end

    # TODO: Verify webhook signature using RevenueCat's webhook authorization header
    # For now, we'll process without verification (add this in production)
    # auth_header = request.env["HTTP_AUTHORIZATION"]

    # Log the webhook event
    Rails.logger.info "RevenueCat webhook received: #{event_data['type']}"

    # Process the event
    handler = Billing::RevenuecatWebhookHandler.new(event_data)
    if handler.process
      head :ok
    else
      head :unprocessable_entity
    end
  end
end
