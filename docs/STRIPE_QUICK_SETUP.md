# Stripe Quick Setup Checklist

Use this checklist to quickly configure Stripe for production. For detailed information, see [STRIPE_SETUP.md](./STRIPE_SETUP.md).

## Prerequisites

- [ ] Stripe account created at https://stripe.com
- [ ] Business details completed in Stripe dashboard
- [ ] Payment processing activated

## Step 1: Rotate API Keys (CRITICAL ⚠️)

⚠️ **The API keys were exposed in git history. You MUST rotate them.**

- [ ] Go to https://dashboard.stripe.com/apikeys
- [ ] Click ⋮ next to "Publishable key" → "Roll key"
- [ ] Click ⋮ next to "Secret key" → "Roll key"
- [ ] Copy both new keys
- [ ] Save to password manager or secure location

## Step 2: Create Products & Prices

### Monthly Plan
- [ ] Go to https://dashboard.stripe.com/products
- [ ] Click "Add product"
- [ ] Name: `AI Talk Coach - Monthly`
- [ ] Price: `€9.99`
- [ ] Billing period: `Monthly`
- [ ] Click "Save product"
- [ ] Copy **Price ID** (starts with `price_...`)

### Yearly Plan
- [ ] Click "Add product"
- [ ] Name: `AI Talk Coach - Yearly`
- [ ] Price: `€60`
- [ ] Billing period: `Yearly`
- [ ] Click "Save product"
- [ ] Copy **Price ID** (starts with `price_...`)

## Step 3: Configure Customer Portal

- [ ] Go to https://dashboard.stripe.com/settings/billing/portal
- [ ] Enable "Customers can update subscriptions"
- [ ] Allow switching between monthly and yearly
- [ ] Configure cancellation flow (choose your preference)
- [ ] Click "Save"

## Step 4: Create Webhook

- [ ] Go to https://dashboard.stripe.com/webhooks
- [ ] Click "Add endpoint"
- [ ] Endpoint URL: `https://app.aitalkcoach.com/webhooks/stripe`
- [ ] Description: `AI Talk Coach Production`
- [ ] Select these events:
  - [ ] `checkout.session.completed`
  - [ ] `customer.subscription.created`
  - [ ] `customer.subscription.updated`
  - [ ] `customer.subscription.deleted`
  - [ ] `invoice.payment_succeeded`
  - [ ] `invoice.payment_failed`
- [ ] Click "Add endpoint"
- [ ] Copy **Signing secret** (starts with `whsec_...`)

## Step 5: Set Environment Variables

Add these to your production server's environment:

```bash
# Stripe Configuration
STRIPE_PUBLISHABLE_KEY=pk_live_[your_new_key_from_step_1]
STRIPE_SECRET_KEY=sk_live_[your_new_key_from_step_1]
STRIPE_WEBHOOK_SECRET=whsec_[your_key_from_step_4]
STRIPE_MONTHLY_PRICE_ID=price_[your_id_from_step_2]
STRIPE_YEARLY_PRICE_ID=price_[your_id_from_step_2]
```

### How to Set (choose your platform):

**Kamal/Docker:**
```bash
# Edit .env file on server
vim /path/to/app/.env
```

**Heroku:**
```bash
heroku config:set STRIPE_PUBLISHABLE_KEY=pk_live_...
heroku config:set STRIPE_SECRET_KEY=sk_live_...
heroku config:set STRIPE_WEBHOOK_SECRET=whsec_...
heroku config:set STRIPE_MONTHLY_PRICE_ID=price_...
heroku config:set STRIPE_YEARLY_PRICE_ID=price_...
```

## Step 6: Test Webhook Delivery

- [ ] Go to your webhook in Stripe dashboard
- [ ] Click "Send test webhook"
- [ ] Select event: `customer.subscription.created`
- [ ] Click "Send test webhook"
- [ ] Check response status is `200 OK`
- [ ] Check your application logs for: `"Stripe event [id] processed successfully"`

## Step 7: Test Subscription Flow

### Use Test Mode First
- [ ] Switch to "Test mode" in Stripe dashboard (toggle in top-right)
- [ ] Use test card: `4242 4242 4242 4242`
- [ ] Any future date for expiry
- [ ] Any 3-digit CVC
- [ ] Complete subscription purchase
- [ ] Verify webhook received in Stripe dashboard
- [ ] Check subscription status in database

### Then Test in Live Mode
- [ ] Switch to "Live mode"
- [ ] Use real payment method
- [ ] Complete test purchase (you can refund it later)
- [ ] Verify webhook received
- [ ] Check subscription activated in database
- [ ] Refund test payment if needed

## Step 8: Enable Payment Notifications

- [ ] Go to https://dashboard.stripe.com/settings/notifications
- [ ] Enable email notifications for:
  - [ ] Failed payments
  - [ ] Disputed charges
  - [ ] Subscription cancellations
- [ ] Add your email address
- [ ] Click "Save"

## Verification Checklist

After completing all steps, verify:

- [ ] API keys are rotated (new keys in use)
- [ ] Old API keys are deleted/deactivated in Stripe
- [ ] Both products (monthly & yearly) created with correct prices
- [ ] Webhook endpoint created with all 6 event types
- [ ] Webhook signing secret saved and configured
- [ ] All 5 environment variables set in production
- [ ] Test webhook delivery successful (200 OK)
- [ ] Test subscription flow successful (test mode)
- [ ] Live subscription flow tested (optional)
- [ ] Email notifications enabled
- [ ] Customer portal configured

## Quick Reference

**Stripe Dashboard URLs:**
- API Keys: https://dashboard.stripe.com/apikeys
- Products: https://dashboard.stripe.com/products
- Webhooks: https://dashboard.stripe.com/webhooks
- Customer Portal: https://dashboard.stripe.com/settings/billing/portal
- Notifications: https://dashboard.stripe.com/settings/notifications

**Test Cards:**
- Success: `4242 4242 4242 4242`
- Decline: `4000 0000 0000 0002`
- Requires authentication: `4000 0025 0000 3155`

## Troubleshooting

**Webhook not receiving events:**
1. Check URL is correct: `https://app.aitalkcoach.com/webhooks/stripe`
2. Verify all 6 events are selected
3. Test delivery from Stripe dashboard
4. Check application logs for errors

**Subscription not activating:**
1. Verify webhook signing secret is correct
2. Check webhook delivery status in Stripe
3. Look for errors in application logs
4. Verify user has `stripe_customer_id` set

**Payment failing:**
1. Check API keys are correct (and rotated)
2. Verify price IDs match your products
3. Check Stripe logs for specific error
4. Ensure payment method is valid

## Next Steps

After Stripe is configured:
1. Review [PRODUCTION_DEPLOYMENT.md](./PRODUCTION_DEPLOYMENT.md) for full deployment
2. Set up remaining environment variables (SMTP, OpenAI, etc.)
3. Run database migrations
4. Deploy application
5. Monitor Stripe dashboard for first 24 hours

## Support

- Stripe Support: https://support.stripe.com
- Stripe Documentation: https://stripe.com/docs
- Application Docs: See [STRIPE_SETUP.md](./STRIPE_SETUP.md) for details
