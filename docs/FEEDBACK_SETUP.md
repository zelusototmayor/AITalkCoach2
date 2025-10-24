# Feedback Feature Setup Guide

## Overview

The feedback feature allows users to submit feedback with optional images directly from the app. Feedback is sent via email to `zsottomayor@gmail.com` without requiring users to enter their email address.

## Features

- **Easy Access**: Click the 💬 button in the bottom-right corner
- **Menu Options**:
  - Share Feedback - Submit text and images
  - Accessibility Settings - Access existing accessibility features
- **Anonymous or Identified**: Automatically includes user info if logged in
- **Image Support**: Users can attach up to 5 images
- **Character Limit**: 5000 characters max for feedback text

## Email Service Setup

You need to configure SMTP settings for email delivery. Choose one of the following options:

### Option 1: Gmail (Recommended for Testing)

**Pros**: Free, easy to set up
**Cons**: Daily sending limits (500 emails/day)

**Setup Steps**:

1. Go to your Google Account settings
2. Enable 2-factor authentication
3. Generate an App Password:
   - Go to https://myaccount.google.com/apppasswords
   - Select "Mail" and your device
   - Copy the generated 16-character password
4. Add to your `.env` file:

```bash
SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_DOMAIN=aitalkcoach.com
SMTP_USERNAME=your-email@gmail.com
SMTP_PASSWORD=your-16-char-app-password
SMTP_AUTHENTICATION=plain
```

### Option 2: SendGrid (Recommended for Production)

**Pros**: Free tier (100 emails/day), reliable, designed for transactional emails
**Cons**: Requires account verification

**Setup Steps**:

1. Sign up at https://sendgrid.com
2. Verify your email and complete account setup
3. Create an API key:
   - Go to Settings > API Keys
   - Create new API key with "Mail Send" permissions
   - Copy the API key (shown only once!)
4. Add to your `.env` file:

```bash
SMTP_ADDRESS=smtp.sendgrid.net
SMTP_PORT=587
SMTP_DOMAIN=aitalkcoach.com
SMTP_USERNAME=apikey
SMTP_PASSWORD=your-sendgrid-api-key-here
SMTP_AUTHENTICATION=plain
```

### Option 3: Postmark

**Pros**: Excellent deliverability, good documentation
**Cons**: Paid service (though affordable)

**Setup Steps**:

1. Sign up at https://postmarkapp.com
2. Create a server and get your Server API Token
3. Add to your `.env` file:

```bash
SMTP_ADDRESS=smtp.postmarkapp.com
SMTP_PORT=587
SMTP_DOMAIN=aitalkcoach.com
SMTP_USERNAME=your-server-api-token
SMTP_PASSWORD=your-server-api-token
SMTP_AUTHENTICATION=plain
```

## Production Deployment

### Environment Variables

Make sure to set these environment variables in your production environment (Heroku, Railway, etc.):

```bash
SMTP_ADDRESS=smtp.sendgrid.net
SMTP_PORT=587
SMTP_DOMAIN=aitalkcoach.com
SMTP_USERNAME=apikey
SMTP_PASSWORD=SG.xxxxx
SMTP_AUTHENTICATION=plain
```

### Heroku Example

```bash
heroku config:set SMTP_ADDRESS=smtp.sendgrid.net
heroku config:set SMTP_PORT=587
heroku config:set SMTP_DOMAIN=aitalkcoach.com
heroku config:set SMTP_USERNAME=apikey
heroku config:set SMTP_PASSWORD=your-sendgrid-api-key
heroku config:set SMTP_AUTHENTICATION=plain
```

## Testing Locally

1. Copy `.env.example` to `.env`
2. Add your SMTP credentials to `.env`
3. Restart your Rails server
4. Visit http://localhost:3000
5. Click the 💬 button in the bottom-right
6. Select "Share Feedback"
7. Submit a test message
8. Check your inbox at zsottomayor@gmail.com

## Troubleshooting

### Email not sending in development

Check your Rails logs for error messages:
```bash
tail -f log/development.log
```

Common issues:
- **Invalid credentials**: Double-check your SMTP username/password
- **Port blocked**: Some ISPs block port 587, try port 465 (SSL) or 2525
- **Gmail blocking**: Make sure you're using an App Password, not your regular password
- **Missing environment variables**: Restart your Rails server after updating `.env`

### Testing email delivery

You can test email delivery in Rails console:

```ruby
rails console

# Send a test feedback email
FeedbackMailer.submit_feedback(
  feedback_text: "Test feedback message",
  user_name: "Test User",
  user_email: "test@example.com",
  images: []
).deliver_now
```

## Email Template

Feedback emails are sent with:
- **To**: zsottomayor@gmail.com
- **From**: noreply@aitalkcoach.com
- **Subject**: New Feedback from AI Talk Coach
- **Reply-To**: User's email (if logged in) or noreply@aitalkcoach.com
- **Content**:
  - Feedback message
  - User name (if logged in) or "Anonymous User"
  - Timestamp
  - Attached images (if provided)

## File Locations

- **Controller**: `app/controllers/feedback_controller.rb`
- **Mailer**: `app/mailers/feedback_mailer.rb`
- **Templates**: `app/views/feedback_mailer/`
- **Stimulus Controller**: `app/javascript/controllers/feedback_menu_controller.js`
- **Styles**: `app/assets/stylesheets/main.css` (bottom of file)
- **Layout**: `app/views/layouts/application.html.erb`
- **Routes**: `config/routes.rb` (POST /feedback)
- **Config**:
  - `config/environments/production.rb`
  - `config/environments/development.rb`

## Security Notes

- CSRF protection is disabled for the feedback endpoint (since it's a public form)
- Maximum 5 images per submission
- Maximum 5000 characters per feedback message
- Images are sent as email attachments (not stored on server)
- User email is never required - system sends on behalf of user

## Future Enhancements

Possible improvements:
- Store feedback in database for admin dashboard
- Add feedback categories (bug, feature request, general)
- Email notifications for feedback responses
- Rate limiting to prevent spam
- Add captcha for anonymous users
