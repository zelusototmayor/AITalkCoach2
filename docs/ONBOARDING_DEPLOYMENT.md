# Onboarding Deployment Guide

This guide covers deploying the complete onboarding system, including profile collection, demo session reuse, payment setup, and trial activation.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Environment Variables](#environment-variables)
- [Database Migrations](#database-migrations)
- [Stripe Configuration](#stripe-configuration)
- [Deployment Steps](#deployment-steps)
- [Post-Deployment Verification](#post-deployment-verification)
- [Cron Job Setup](#cron-job-setup)
- [Monitoring](#monitoring)
- [Rollback Procedure](#rollback-procedure)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

Before deploying, ensure you have:

- [ ] Ruby 3.x installed on production server
- [ ] Rails 7.x configured
- [ ] PostgreSQL database accessible
- [ ] Stripe account with API keys
- [ ] SSL certificate for HTTPS (required for Stripe)
- [ ] Email delivery configured (for onboarding emails)
- [ ] Redis installed (for background jobs)
- [ ] Sufficient storage for trial session media files

---

## Environment Variables

Add these to your production environment (`.env.production` or hosting provider settings):

```bash
# Stripe API Keys
STRIPE_PUBLISHABLE_KEY=pk_live_... # From https://dashboard.stripe.com/apikeys
STRIPE_SECRET_KEY=sk_live_...      # From https://dashboard.stripe.com/apikeys

# Stripe Webhook Secret
STRIPE_WEBHOOK_SECRET=whsec_...    # Created in Stripe Dashboard → Webhooks

# Stripe Price IDs
STRIPE_MONTHLY_PRICE_ID=price_...  # Monthly product price ID
STRIPE_YEARLY_PRICE_ID=price_...   # Yearly product price ID

# Application URLs
APP_DOMAIN=app.aitalkcoach.com
MARKETING_DOMAIN=aitalkcoach.com

# Email Configuration (for onboarding emails)
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USERNAME=your-smtp-username
SMTP_PASSWORD=your-smtp-password
FROM_EMAIL=noreply@aitalkcoach.com

# Redis (for Sidekiq background jobs)
REDIS_URL=redis://localhost:6379/0

# Sentry (optional, for error tracking)
SENTRY_DSN=https://...@sentry.io/...
```

**Security Note**: Never commit these to version control. Use environment-specific configuration or a secrets manager.

---

## Database Migrations

Run these migrations in order:

### 1. Onboarding Fields Migration

```bash
# Check if migration exists
rails db:migrate:status | grep add_onboarding_to_users

# Run migration
rails db:migrate VERSION=20251024145300  # add_subscription_to_users
rails db:migrate VERSION=20251027181056  # add_onboarding_to_users
rails db:migrate VERSION=20251027184857  # add_trial_starts_at_to_users
rails db:migrate VERSION=20251027185221  # add_stripe_payment_method_id_to_users
```

### 2. Stripe Events Migration

```bash
rails db:migrate VERSION=20251024145304  # create_stripe_events
```

### 3. Verify Schema

```bash
rails runner "puts User.column_names.grep(/onboarding|trial|stripe/).inspect"
# Should output: ["onboarding_completed_at", "onboarding_demo_session_id", "trial_starts_at", "trial_expires_at", "stripe_customer_id", "stripe_payment_method_id", "subscription_plan", "subscription_status", ...]
```

---

## Stripe Configuration

### 1. Create Products in Stripe Dashboard

1. Visit https://dashboard.stripe.com/products
2. Click **"Add Product"**

**Monthly Plan:**
- Name: `AI Talk Coach - Monthly`
- Description: `Monthly subscription to AI Talk Coach`
- Pricing Model: `Recurring`
- Price: `€9.99`
- Billing Period: `Monthly`
- Copy the **Price ID** (e.g., `price_1ABC123...`)

**Yearly Plan:**
- Name: `AI Talk Coach - Yearly`
- Description: `Yearly subscription to AI Talk Coach (50% savings)`
- Pricing Model: `Recurring`
- Price: `€60`
- Billing Period: `Yearly`
- Copy the **Price ID** (e.g., `price_1XYZ789...`)

### 2. Configure Customer Portal

1. Go to https://dashboard.stripe.com/settings/billing/portal
2. Enable **"Allow customers to update subscriptions"**
3. Add both Monthly and Yearly plans to allowed switches
4. Configure cancellation flow:
   - ☑ Cancel immediately
   - ☑ Cancel at period end
5. Save configuration

### 3. Set Up Webhook Endpoint

1. Go to https://dashboard.stripe.com/webhooks
2. Click **"Add endpoint"**
3. URL: `https://app.aitalkcoach.com/webhooks/stripe`
4. Select events:
   - `customer.subscription.created`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
   - `invoice.payment_succeeded`
   - `invoice.payment_failed`
   - `payment_intent.succeeded`
   - `payment_intent.payment_failed`
5. Click **"Add endpoint"**
6. Copy the **Signing Secret** (starts with `whsec_...`)
7. Add to environment as `STRIPE_WEBHOOK_SECRET`

### 4. Test Webhook Delivery

```bash
# From your local machine
curl -X POST https://app.aitalkcoach.com/webhooks/stripe \
  -H "Content-Type: application/json" \
  -d '{"type": "ping"}'

# Should return 200 OK
```

---

## Deployment Steps

### Step 1: Backup Database

```bash
# On production server
pg_dump -U postgres -d aitalkcoach_production > backup_$(date +%Y%m%d_%H%M%S).sql
```

### Step 2: Pull Latest Code

```bash
git fetch origin
git checkout main
git pull origin main
```

### Step 3: Install Dependencies

```bash
bundle install --deployment --without development test
yarn install --frozen-lockfile
```

### Step 4: Run Migrations

```bash
RAILS_ENV=production rails db:migrate
```

### Step 5: Precompile Assets

```bash
RAILS_ENV=production rails assets:precompile
```

### Step 6: Restart Application Server

```bash
# For Passenger
passenger-config restart-app /path/to/app

# For Puma
systemctl restart puma

# For Capistrano
cap production deploy:restart
```

### Step 7: Restart Background Workers

```bash
# Restart Sidekiq
systemctl restart sidekiq

# Or if using process manager
bundle exec sidekiqctl restart /tmp/sidekiq.pid
```

---

## Post-Deployment Verification

### 1. Health Check

```bash
# Check app is running
curl https://app.aitalkcoach.com/health
# Expected: {"status":"ok"}

# Check Stripe integration
rails runner "puts Stripe::Account.retrieve.id"
# Should output your Stripe account ID
```

### 2. Test Onboarding Flow

1. Open incognito browser
2. Visit `https://aitalkcoach.com`
3. Complete demo on landing page
4. Sign up for account
5. Verify redirect to onboarding welcome screen
6. Progress through all 5 screens
7. Add test payment method (use `4242 4242 4242 4242`)
8. Verify redirect to dashboard
9. Check trial banner appears in sidebar

### 3. Verify Database

```bash
rails console
> user = User.last
> user.onboarding_completed_at.present? # => true
> user.trial_expires_at > Time.current # => true
> user.subscription_status # => "free_trial"
> user.stripe_payment_method_id.present? # => true
```

### 4. Check Background Jobs

```bash
# View Sidekiq dashboard
open https://app.aitalkcoach.com/sidekiq

# Check for failed jobs
rails runner "puts Sidekiq::Stats.new.failed"
# Should be 0 or low number
```

---

## Cron Job Setup

The onboarding system requires a daily billing job to charge users whose trials have expired.

### Option 1: Using Whenever Gem (Recommended)

1. **Add to Gemfile** (if not already present):

```ruby
gem 'whenever', require: false
```

2. **Create `config/schedule.rb`**:

```ruby
# config/schedule.rb
set :output, "log/cron.log"
set :environment, ENV['RAILS_ENV'] || 'production'

# Run daily billing at midnight UTC
every 1.day, at: '12:00 am' do
  rake "billing:charge_expired_trials"
end

# Optional: Preview billing at 11 PM (before midnight charge)
every 1.day, at: '11:00 pm' do
  rake "billing:preview_expired_trials"
end

# Clean up old trial sessions weekly
every :sunday, at: '2:00 am' do
  rake "trial_sessions:cleanup_expired"
end
```

3. **Update crontab**:

```bash
# On production server
bundle exec whenever --update-crontab --set environment='production'

# Verify crontab
crontab -l
# Should show:
# 0 0 * * * /bin/bash -l -c 'cd /path/to/app && RAILS_ENV=production bundle exec rake billing:charge_expired_trials'
```

### Option 2: Manual Cron Setup

If not using Whenever, add directly to crontab:

```bash
crontab -e

# Add these lines:
# Daily billing at midnight UTC
0 0 * * * cd /path/to/aitalkcoach && RAILS_ENV=production /usr/bin/bundle exec rake billing:charge_expired_trials >> log/cron.log 2>&1

# Preview billing at 11 PM
0 23 * * * cd /path/to/aitalkcoach && RAILS_ENV=production /usr/bin/bundle exec rake billing:preview_expired_trials >> log/cron.log 2>&1
```

### Option 3: Using Heroku Scheduler

If deploying to Heroku:

```bash
# Add Heroku Scheduler addon
heroku addons:create scheduler:standard

# Open scheduler dashboard
heroku addons:open scheduler

# Add job:
# - Command: bundle exec rake billing:charge_expired_trials
# - Frequency: Daily
# - Time: 00:00 UTC
```

### Verify Cron Job Execution

```bash
# Check cron log
tail -f log/cron.log

# Test rake task manually first
RAILS_ENV=production bundle exec rake billing:preview_expired_trials

# If output looks good, test actual charge (with test user)
RAILS_ENV=production bundle exec rake billing:test_charge[USER_ID]
```

---

## Monitoring

### 1. Daily Onboarding Metrics

Run this daily to track onboarding health:

```bash
RAILS_ENV=production bundle exec rake onboarding:stats
```

Expected output:
```
============================================================
Onboarding Stats for 2025-01-27
============================================================
New signups today: 15
Onboarding completion rate: 73.3% (11/15)
Demo reuse rate: 60.0% (9/15)
Payment collection success: 91.0% (10/11)
============================================================
```

### 2. Billing Monitoring

```bash
# Preview who will be charged tonight
RAILS_ENV=production bundle exec rake billing:preview_expired_trials
```

### 3. Application Logs

Monitor logs for onboarding-related issues:

```bash
# Tail production logs
tail -f log/production.log | grep -i "onboarding\|stripe\|billing"

# Search for errors
grep -i "error\|failed" log/production.log | grep -i "onboarding"
```

### 4. Stripe Dashboard Monitoring

- **Failed Payments**: https://dashboard.stripe.com/payments?status[]=failed
- **Webhooks**: https://dashboard.stripe.com/webhooks (check for failed deliveries)
- **Customers**: https://dashboard.stripe.com/customers

### 5. Set Up Alerts

Configure alerts for critical issues:

**Via Sentry** (if installed):
- Stripe webhook failures
- Payment processing errors
- Onboarding completion drops below 50%

**Via Email/Slack**:
```ruby
# In lib/tasks/onboarding.rake
if completion_rate < 0.5
  AdminMailer.onboarding_alert("Completion rate dropped to #{completion_rate}").deliver_now
end
```

---

## Rollback Procedure

If deployment causes critical issues:

### 1. Immediate Rollback (Code Only)

```bash
# Revert to previous release
git checkout <previous-commit-sha>
bundle install
RAILS_ENV=production rails assets:precompile
systemctl restart puma sidekiq
```

### 2. Database Rollback (If Needed)

```bash
# Check current migration version
rails db:version

# Rollback specific migrations
rails db:migrate:down VERSION=20251027185221
rails db:migrate:down VERSION=20251027184857
rails db:migrate:down VERSION=20251027181056
```

### 3. Restore Database Backup (Last Resort)

```bash
# Stop application
systemctl stop puma sidekiq

# Restore backup
psql -U postgres -d aitalkcoach_production < backup_YYYYMMDD_HHMMSS.sql

# Start application
systemctl start puma sidekiq
```

---

## Troubleshooting

### Issue: Users not redirected to onboarding after signup

**Solution:**
1. Check `Auth::RegistrationsController#create` redirects to `onboarding_welcome_path`
2. Verify routes are loaded:
   ```bash
   rails routes | grep onboarding
   ```
3. Check application logs for redirect loops

### Issue: Demo session not linked during onboarding

**Solution:**
1. Verify cookie is set on landing page:
   ```javascript
   console.log(document.cookie); // Should contain demo_trial_token
   ```
2. Check cookie expiration (should be 1 hour)
3. Ensure demo session is completed (not pending/failed)
4. Check `OnboardingController#test` is reading cookie correctly

### Issue: Stripe payment fails during onboarding

**Solution:**
1. Check Stripe API keys are correct
2. Verify webhook secret is configured
3. Test Stripe connection:
   ```bash
   rails runner "puts Stripe::Account.retrieve.inspect"
   ```
4. Check Stripe dashboard for specific error
5. Ensure HTTPS is enabled (Stripe requires SSL)

### Issue: Trial not extending after session completion

**Solution:**
1. Verify user is on `free_trial` status:
   ```ruby
   user.subscription_status # => "free_trial"
   ```
2. Check session duration ≥ 60 seconds
3. Review `Sessions::ProcessJob#extend_trial_if_qualified` logic
4. Check logs for "Extended trial for user" message

### Issue: Billing cron job not running

**Solution:**
1. Verify crontab is installed:
   ```bash
   crontab -l
   ```
2. Check cron log for errors:
   ```bash
   tail -f log/cron.log
   ```
3. Test rake task manually:
   ```bash
   bundle exec rake billing:preview_expired_trials
   ```
4. Ensure cron service is running:
   ```bash
   systemctl status cron
   ```

---

## Success Metrics

After deployment, track these metrics to measure success:

| Metric | Target | How to Measure |
|--------|--------|----------------|
| Onboarding completion rate | >70% | `rake onboarding:stats` |
| Demo reuse rate | >50% | `rake onboarding:stats` |
| Payment collection success | >90% | `rake onboarding:stats` |
| Time to complete onboarding | <5 min | User analytics |
| Trial to paid conversion | >30% | Stripe dashboard |

---

## Additional Resources

- [Stripe Setup Guide](./STRIPE_SETUP.md)
- [Onboarding Implementation Plan](./ONBOARDING_IMPLEMENTATION.md)
- [Stripe API Documentation](https://stripe.com/docs/api)
- [Stripe Webhook Testing](https://stripe.com/docs/webhooks/test)

---

## Support

For deployment issues, contact:
- **Technical Lead**: [email]
- **DevOps Team**: [email]
- **Stripe Support**: https://support.stripe.com/

---

*Last updated: 2025-01-27*
