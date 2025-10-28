# Production Deployment Guide

This guide covers the critical steps for deploying AI Talk Coach to production.

## Pre-Deployment Checklist

### 1. Rotate Stripe API Keys (CRITICAL)

⚠️ **URGENT**: The Stripe API keys were temporarily exposed in git history. You MUST rotate them before deployment.

1. Go to https://dashboard.stripe.com/apikeys
2. Click the ⋮ menu next to each key → "Roll key"
3. Copy the new keys and store them securely
4. Update your production environment variables with the new keys

### 2. Database Migrations

Run all pending migrations on production:

```bash
# On your production server
bin/rails db:migrate RAILS_ENV=production
```

**New migrations to run:**
- `20251024145300_add_subscription_to_users.rb` - Adds subscription fields
- `20251024145304_create_stripe_events.rb` - Creates stripe_events table
- `20251027181056_add_onboarding_to_users.rb` - Adds onboarding fields
- `20251027184857_add_trial_starts_at_to_users.rb` - Adds trial tracking
- `20251027185221_add_stripe_payment_method_id_to_users.rb` - Adds payment method
- `20251027232431_change_user_speaking_goal_to_array.rb` - Changes goal to array
- `20251028103651_add_error_fields_to_trial_sessions.rb` - Adds error tracking
- `20251028195610_add_payment_retry_count_to_users.rb` - Adds retry counter

### 3. Initialize Trials for Existing Users

If you have existing users, initialize their trial status:

```ruby
# In Rails console on production (rails c production)
User.where(trial_expires_at: nil).find_each do |user|
  user.update!(
    trial_expires_at: 24.hours.from_now,
    subscription_status: 'free_trial'
  )
end

# Verify
puts "Users on trial: #{User.where(subscription_status: 'free_trial').count}"
```

## Environment Variables

### Required for Production

Set these environment variables on your production server:

```bash
# AI Services (REQUIRED)
OPENAI_API_KEY=sk-...                     # Get from: https://platform.openai.com/api-keys
DEEPGRAM_API_KEY=...                       # Get from: https://console.deepgram.com

# Stripe (REQUIRED - use ROTATED keys)
STRIPE_PUBLISHABLE_KEY=pk_live_...         # From: https://dashboard.stripe.com/apikeys
STRIPE_SECRET_KEY=sk_live_...              # From: https://dashboard.stripe.com/apikeys
STRIPE_WEBHOOK_SECRET=whsec_...            # From: https://dashboard.stripe.com/webhooks
STRIPE_MONTHLY_PRICE_ID=price_...          # From your Stripe product
STRIPE_YEARLY_PRICE_ID=price_...           # From your Stripe product

# Email (REQUIRED)
SMTP_ADDRESS=smtp.gmail.com                # Or your SMTP provider
SMTP_PORT=587
SMTP_DOMAIN=aitalkcoach.com
SMTP_USERNAME=your-email@aitalkcoach.com
SMTP_PASSWORD=your-app-password            # Gmail: https://support.google.com/accounts/answer/185833
SMTP_AUTHENTICATION=plain

# Error Monitoring (RECOMMENDED)
SENTRY_DSN=https://...@sentry.io/...       # Get from: https://sentry.io

# Application Settings (OPTIONAL)
RAILS_LOG_LEVEL=info                       # Or 'warn' for less verbose logging
DB_POOL_SIZE=25                            # Database connection pool size
DB_CHECKOUT_TIMEOUT=10                     # Database checkout timeout in seconds
```

### How to Set Environment Variables

**On Kamal/Docker:**
```bash
# Edit .env file on server
vim .env

# Or set via Kamal secrets
kamal env set OPENAI_API_KEY=sk-...
```

**On Heroku:**
```bash
heroku config:set OPENAI_API_KEY=sk-...
heroku config:set STRIPE_SECRET_KEY=sk_live_...
# etc.
```

**On other platforms:**
Consult your platform's documentation for setting environment variables.

## Stripe Setup

### 1. Create Products

1. Go to https://dashboard.stripe.com/products
2. Click "Add product"
3. Create monthly plan:
   - Name: "AI Talk Coach - Monthly"
   - Price: €9.99/month
   - Recurring: Monthly
   - Copy the **Price ID** (starts with `price_...`)
4. Create yearly plan:
   - Name: "AI Talk Coach - Yearly"
   - Price: €60/year
   - Recurring: Yearly
   - Copy the **Price ID**

### 2. Configure Webhook

1. Go to https://dashboard.stripe.com/webhooks
2. Click "Add endpoint"
3. Endpoint URL: `https://app.aitalkcoach.com/webhooks/stripe`
4. Select these events:
   - `checkout.session.completed`
   - `customer.subscription.created`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
   - `invoice.payment_succeeded`
   - `invoice.payment_failed`
5. Copy the **Signing secret** (starts with `whsec_...`)
6. Add it to your environment as `STRIPE_WEBHOOK_SECRET`

### 3. Test Webhook Delivery

```bash
# Send test event from Stripe dashboard
# Go to: https://dashboard.stripe.com/webhooks/[webhook_id]
# Click "Send test webhook"
# Select: customer.subscription.created

# Check your application logs for:
# "Stripe event [event_id] processed successfully"
```

## Post-Deployment Verification

### 1. Health Checks

```bash
# Check application is running
curl https://app.aitalkcoach.com/up

# Should return: HTTP 200 OK
```

### 2. Test Onboarding Flow

1. Visit https://aitalkcoach.com
2. Sign up with a test email
3. Complete the onboarding flow
4. Verify trial is active (24 hours)
5. Complete a session (1+ minute)
6. Verify trial extends (check logs)

### 3. Test Subscription Flow (Use Stripe Test Mode)

For testing in production, use Stripe test mode:

1. Switch to test mode in Stripe dashboard
2. Use test card: `4242 4242 4242 4242`
3. Complete subscription purchase
4. Check webhook delivery in Stripe dashboard
5. Verify subscription status in database:
   ```ruby
   user = User.find_by(email: 'test@example.com')
   user.subscription_status  # Should be 'active'
   user.subscription_plan     # Should be 'monthly' or 'yearly'
   ```

### 4. Monitor Logs

```bash
# Watch logs for errors
tail -f log/production.log

# Look for:
# - "Extended trial for user X"
# - "Subscription created for user X"
# - "Payment succeeded for user X"
# - Any ERROR or WARN messages
```

## Monitoring & Alerts

### What to Monitor

1. **Stripe Dashboard** (https://dashboard.stripe.com)
   - Failed payments
   - Subscription cancellations
   - Revenue metrics
   - Webhook delivery status

2. **Application Logs**
   - Payment retry attempts
   - Trial extensions
   - Subscription status changes
   - Error patterns

3. **Database Queries**
   ```sql
   -- Users by subscription status
   SELECT subscription_status, COUNT(*)
   FROM users
   GROUP BY subscription_status;

   -- Failed payment retries
   SELECT email, payment_retry_count, subscription_status
   FROM users
   WHERE payment_retry_count > 0;

   -- Expiring trials (next 24h)
   SELECT COUNT(*)
   FROM users
   WHERE subscription_status = 'free_trial'
   AND trial_expires_at < datetime('now', '+24 hours');
   ```

### Set Up Alerts

**Stripe:**
1. Go to https://dashboard.stripe.com/settings/notifications
2. Enable alerts for:
   - Failed payments
   - Disputed charges
   - Subscription cancellations

**Sentry:**
1. Configure alerts for error rate spikes
2. Set up Slack/email notifications

## Backup Strategy

### Database Backups

**SQLite Backups:**
```bash
# Create backup script
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
sqlite3 storage/production.sqlite3 ".backup storage/backups/production_$DATE.sqlite3"

# Keep only last 30 days
find storage/backups -name "production_*.sqlite3" -mtime +30 -delete
```

**Automate backups:**
```bash
# Add to crontab
0 */6 * * * /path/to/backup_script.sh  # Every 6 hours
```

### Critical Data

- `storage/production.sqlite3` - Main database
- `storage/production_cache.sqlite3` - Cache (optional)
- `storage/production_queue.sqlite3` - Jobs (optional)
- `storage/[audio-files]` - User recordings

## Rollback Plan

If deployment fails:

```bash
# 1. Rollback code
git revert HEAD
git push origin main

# 2. Rollback database (if needed)
bin/rails db:rollback RAILS_ENV=production

# 3. Restore from backup (if needed)
cp storage/backups/production_[timestamp].sqlite3 storage/production.sqlite3

# 4. Restart application
kamal deploy  # or your deployment command
```

## Security Checklist

- [ ] Stripe API keys rotated and secured
- [ ] Environment variables not committed to git
- [ ] SSL/HTTPS enforced (check `force_ssl: true`)
- [ ] Webhook signatures verified
- [ ] SMTP credentials secured
- [ ] Error tracking configured (Sentry)
- [ ] Regular database backups scheduled
- [ ] Host authorization configured
- [ ] Session secrets properly set

## Support & Troubleshooting

### Common Issues

**Webhooks Not Processing:**
- Check webhook signing secret matches
- Verify URL is accessible: `curl https://app.aitalkcoach.com/webhooks/stripe`
- Check Stripe dashboard for delivery attempts
- Look for errors in application logs

**Payments Failing:**
- Check Stripe API keys are correct
- Verify payment method is valid
- Check for Stripe API errors in logs
- Review failed payment in Stripe dashboard

**Trial Not Extending:**
- Verify session duration ≥60 seconds
- Check user status is 'free_trial'
- Look for "Extended trial for user" in logs
- Verify job processing: `SELECT * FROM solid_queue_jobs WHERE status = 'failed'`

### Getting Help

- **Stripe Issues**: https://support.stripe.com
- **Application Issues**: Check application logs
- **Server Issues**: Check with your hosting provider
