# Stripe configuration
# API keys should be stored in environment variables for production
# For development, you can use .env file with dotenv-rails gem

Rails.configuration.stripe = {
  publishable_key: ENV.fetch("STRIPE_PUBLISHABLE_KEY", Rails.env.development? ? "pk_test_placeholder" : nil),
  secret_key: ENV.fetch("STRIPE_SECRET_KEY", Rails.env.development? ? "sk_test_placeholder" : nil),
  webhook_secret: ENV.fetch("STRIPE_WEBHOOK_SECRET", nil)
}

Stripe.api_key = Rails.configuration.stripe[:secret_key]

# Set API version to ensure consistent behavior
Stripe.api_version = "2024-11-20.acacia"

# Configure logging in development
if Rails.env.development?
  Stripe.log_level = Stripe::LEVEL_INFO
end
