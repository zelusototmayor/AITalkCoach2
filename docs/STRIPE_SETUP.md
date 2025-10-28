# Stripe Subscription Setup Guide

This document explains the Stripe integration for AI Talk Coach's subscription system.

## Overview

The subscription system implements:
- **Free Trial**: Daily-engagement model - users get 24 hours free, extended by completing 1+ minute sessions
- **Monthly Plan**: €9.99/month
- **Yearly Plan**: €60/year (50% savings)
- **Stripe Checkout**: Pre-built checkout flow for payment collection
- **Webhook Integration**: Automatic subscription status updates

## Initial Setup

### 1. Create Stripe Products & Prices

In your Stripe Dashboard (https://dashboard.stripe.com):

1. **Create Products**:
   - Go to Products → Add Product
   - Name: "AI Talk Coach - Monthly"
   - Price: €9.99/month, recurring monthly
   - Copy the **Price ID** (starts with `price_...`)

   - Name: "AI Talk Coach - Yearly"
   - Price: €60/year, recurring yearly
   - Copy the **Price ID** (starts with `price_...`)

2. **Configure Customer Portal**:
   - Go to Settings → Customer portal
   - Enable "Allow customers to update subscriptions"
   - Enable plan changes between monthly and yearly
   - Configure cancellation flow

### 2. Set Environment Variables

Add these to your `.env` file:

```bash
# Stripe API Keys (from https://dashboard.stripe.com/apikeys)
STRIPE_PUBLISHABLE_KEY=pk_live_xxxxxxxxxxxxxxxxxxxxx
STRIPE_SECRET_KEY=sk_live_xxxxxxxxxxxxxxxxxxxxx

# Webhook Secret (created in step 3)
STRIPE_WEBHOOK_SECRET=whsec_...

# Price IDs (from your Stripe products)
STRIPE_MONTHLY_PRICE_ID=price_xxxxxxxxxxxxx
STRIPE_YEARLY_PRICE_ID=price_xxxxxxxxxxxxx
```

### 3. Set Up Webhook Endpoint

**Production Setup**:
1. Go to Stripe Dashboard → Developers → Webhooks
2. Click "Add endpoint"
3. URL: `https://app.aitalkcoach.com/webhooks/stripe`
4. Select events to listen for:
   - `customer.subscription.created`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
   - `invoice.payment_succeeded`
   - `invoice.payment_failed`
5. Copy the **Signing secret** (starts with `whsec_...`)
6. Add it to your `.env` as `STRIPE_WEBHOOK_SECRET`

**Development Setup**:
Use Stripe CLI for local testing:

```bash
# Install Stripe CLI
brew install stripe/stripe-cli/stripe

# Login to your Stripe account
stripe login

# Forward webhooks to local server
stripe listen --forward-to https://aitalkcoach.local:3000/webhooks/stripe

# Copy the webhook secret from output and add to .env
```

### 4. Update Existing Users

Run this command to initialize trial for existing users:

```ruby
# In Rails console (rails c)
User.where(trial_expires_at: nil).update_all(
  trial_expires_at: 24.hours.from_now,
  subscription_status: 'free_trial'
)
```

## How It Works

### Free Trial System

1. **Sign Up**: New users get `trial_expires_at = 24.hours.from_now`
2. **Complete Session**: After processing a session ≥60 seconds, `extend_trial!` is called
3. **Trial Extension**: `trial_expires_at` is reset to 24 hours from now
4. **Access Control**: `can_access_app?` checks if trial is active or subscription is paid

Key code locations:
- Trial initialization: `app/models/user.rb:142` (after_create :initialize_trial)
- Trial extension: `app/jobs/sessions/process_job.rb:580` (extend_trial_if_qualified)
- Access control: `app/controllers/application_controller.rb:103` (require_subscription)

### Subscription Flow

1. **User clicks "Subscribe"** on pricing page (`/pricing`)
2. **Redirected to Stripe Checkout** via `Billing::CheckoutService`
3. **Payment processed** by Stripe
4. **Webhook received** at `/webhooks/stripe`
5. **Subscription activated** via `Billing::WebhookHandler`
6. **User updated** with subscription details

### Webhook Processing

Webhooks are processed idempotently using the `stripe_events` table:

```ruby
# app/services/billing/webhook_handler.rb
def process
  return if StripeEvent.processed?(event.id) # Prevent duplicate processing

  # Store event
  stripe_event = StripeEvent.create!(stripe_event_id: event.id, ...)

  # Process based on type
  case event.type
  when 'customer.subscription.created' then handle_subscription_created
  # ...
  end

  stripe_event.mark_as_processed!
end
```

## Testing

### Test Subscription Flow

1. **Sign up** as a new user
2. **Verify trial**: Check sidebar shows "FREE TRIAL" banner with hours remaining
3. **Complete a session** (1+ minute long)
4. **Check logs**: Should see "Extended trial for user X until..."
5. **Wait 24+ hours** (or manually expire trial in console)
6. **Try to access app**: Should redirect to pricing page
7. **Subscribe** via pricing page (use Stripe test card: `4242 4242 4242 4242`)
8. **Verify access**: Should be able to access app again

### Test Webhooks Locally

```bash
# Terminal 1: Start Rails server
bin/rails server

# Terminal 2: Forward Stripe webhooks
stripe listen --forward-to https://aitalkcoach.local:3000/webhooks/stripe

# Terminal 3: Trigger test events
stripe trigger customer.subscription.created
stripe trigger customer.subscription.updated
stripe trigger invoice.payment_succeeded
```

### Useful Test Commands

```ruby
# Rails console (rails c)

# Check user subscription status
user = User.find_by(email: 'test@example.com')
user.subscription_status
user.trial_active?
user.subscription_active?
user.can_access_app?

# Manually extend trial
user.extend_trial!

# Manually expire trial
user.update(trial_expires_at: 1.hour.ago)

# Simulate subscription activation
user.update(
  subscription_status: 'active',
  subscription_plan: 'monthly',
  current_period_end: 1.month.from_now
)
```

## Routes

### Main Site (aitalkcoach.com)
- `GET /pricing` → Pricing page with both plans

### App Subdomain (app.aitalkcoach.com)
- `POST /subscriptions?plan=monthly` → Redirect to Stripe Checkout (monthly)
- `POST /subscriptions?plan=yearly` → Redirect to Stripe Checkout (yearly)
- `GET /subscriptions/:id` → View subscription details
- `POST /subscriptions/manage` → Redirect to Stripe Customer Portal
- `GET /subscriptions/success` → Success page after checkout
- `POST /webhooks/stripe` → Stripe webhook endpoint

## Key Files

### Models
- `app/models/user.rb` - User subscription methods
- `app/models/stripe_event.rb` - Webhook idempotency tracking

### Controllers
- `app/controllers/pricing_controller.rb` - Public pricing page
- `app/controllers/subscriptions_controller.rb` - Subscription management
- `app/controllers/webhooks_controller.rb` - Stripe webhook handler
- `app/controllers/application_controller.rb` - Access control filters

### Services
- `app/services/billing/checkout_service.rb` - Checkout session creation
- `app/services/billing/webhook_handler.rb` - Webhook event processing

### Views
- `app/views/pricing/index.html.erb` - Pricing page
- `app/views/subscriptions/show.html.erb` - Subscription management page
- `app/views/shared/_sidebar.html.erb` - Navigation with billing link

### Jobs
- `app/jobs/sessions/process_job.rb:580` - Trial extension logic

### Config
- `config/initializers/stripe.rb` - Stripe API configuration
- `config/routes.rb` - Routing for pricing, subscriptions, webhooks

## Deployment Checklist

- [ ] Create Stripe products with correct prices (€9.99/month, €60/year)
- [ ] Copy Price IDs to environment variables
- [ ] Add Stripe API keys to production environment
- [ ] Set up webhook endpoint in Stripe dashboard
- [ ] Add webhook secret to production environment
- [ ] Test webhook delivery in production
- [ ] Run migration to initialize trials for existing users
- [ ] Test complete subscription flow in production
- [ ] Monitor Stripe dashboard for successful payments
- [ ] Set up Stripe alerts for failed payments

## Monitoring

### What to Monitor

1. **Stripe Dashboard**:
   - Failed payments
   - Subscription cancellations
   - Revenue metrics

2. **Application Logs**:
   - `grep "Extended trial for user"` - Trial extensions working
   - `grep "Stripe webhook"` - Webhook processing
   - `grep "Stripe checkout error"` - Checkout failures

3. **Database Queries**:
   ```sql
   -- Users by subscription status
   SELECT subscription_status, COUNT(*) FROM users GROUP BY subscription_status;

   -- Trial expirations in next 24h
   SELECT COUNT(*) FROM users
   WHERE subscription_status = 'free_trial'
   AND trial_expires_at < NOW() + INTERVAL '24 hours';
   ```

## Troubleshooting

### Webhook not processing
- Check webhook signature is correct in `.env`
- Verify URL is accessible: `curl -X POST https://app.aitalkcoach.com/webhooks/stripe`
- Check Stripe dashboard → Webhooks → Attempts for error details

### Trial not extending
- Check session duration: must be ≥60 seconds
- Check user status: must be `subscription_status = 'free_trial'`
- Check logs for "Session X qualifies for trial extension"

### Subscription not activating after payment
- Check webhook was received (Stripe dashboard → Webhooks → Events)
- Check `stripe_events` table for event processing
- Check user record for updated `subscription_status` and `stripe_customer_id`

## Security Notes

- API keys are stored in environment variables, never in code
- Webhook signatures are verified before processing
- Idempotency prevents duplicate event processing
- HTTPS required for all webhook endpoints
- Rate limiting should be configured via Rack::Attack

## Future Enhancements

Possible improvements to consider:

1. **Dunning Management**: Handle failed payments with retry logic
2. **Usage-Based Billing**: Charge per session instead of flat subscription
3. **Team Plans**: Multiple users under one subscription
4. **Discount Codes**: Promotional pricing support
5. **Grace Period**: Allow continued access for 1-3 days after expiration
6. **Email Notifications**: Trial expiring reminders, payment receipts
7. **Analytics**: Track conversion rates, churn, MRR
