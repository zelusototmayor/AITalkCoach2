# Analytics Quick Reference

## At a Glance

### Initialization Locations
- **Web:** `/app/views/layouts/application.html.erb` (lines 13-53)
- **Mobile:** `/mobile/App.js` (lines 56-72)

### Core Service Files
- **Mobile Analytics Service:** `/mobile/services/analytics.js` (Singleton pattern)
- **Web Analytics Controller:** `/app/javascript/controllers/analytics_controller.js`
- **Rails Helper:** `/app/helpers/mixpanel_helper.rb`

### Credentials
- **Mixpanel Token:** `44bf717b1ffcda5744f92721374b15da`
- **GA Measurement ID:** `G-KM66Q2D5T3`

---

## Event Tracking Locations

### Authentication Flow
- **Mobile:** `mobile/context/AuthContext.js` (lines 114-214)
  - User Signed Up, User Logged In, Login Failed, etc.
- **Web:** `app/javascript/controllers/analytics_controller.js` (lines 122-125)
  - User Logged In event

### Recording & Sessions
- **Mobile:** `mobile/screens/practice/PracticeScreen.js` (lines 273, 369, 407, etc.)
  - Recording Started/Stopped/Error
- **Mobile:** `mobile/screens/practice/SessionProcessingScreen.js` (lines 31-144)
  - Session Processing events
- **Web:** `app/javascript/controllers/recorder_controller.js` (lines 1314-1341)
  - Session completion tracking

### Navigation
- **Mobile:** `mobile/App.js` (lines 32-47)
  - Screen view tracking via navigation handler

---

## Key Events Tracked

### Authentication (8 events)
- User Signed Up
- User Logged In
- Login Failed / Error
- Signup Failed / Error
- User Logged Out
- Onboarding Completed

### Recording (8 events)
- Recording Started
- Recording Stopped
- Recording Error
- Recording Start Failed
- Microphone Permission (Granted/Denied/Error)
- Prompt Shuffled
- Time Duration Selected

### Session Processing (8 events)
- Session Processing Started/Completed/Failed
- Session Upload Started/Completed
- Session Processing Progress (milestone tracking)
- Session Relevance Failed
- Session Incomplete

### Conversion (5 events)
- Trial Started
- Trial Completed
- Trial Analysis View
- Real Session Started/Completed
- Real Analysis View
- Landing Page View
- Signup Clicked/Completed

**Total: 30+ events tracked**

---

## User Properties Captured

### Mobile (Mixpanel)
- `$name`, `$email`, `$created` (standard)
- `onboarding_completed`, `preferred_language`
- `communication_style`, `age_range`

### Web (Mixpanel & GA)
- `$name`, `$email`, `$created` (Mixpanel)
- `User Type` (authenticated/trial/anonymous)
- `Platform` (Web)

### Super Properties (Sent with Every Event)
**Mobile:**
- Platform (ios/android)
- App version
- Device model
- OS version

**Web:**
- User Type
- Environment
- Platform (Web)
- Page URL
- Page Title

---

## Issues Summary

### Critical (Must Fix)
1. Mobile missing Google Analytics
2. Mobile using US endpoint instead of EU
3. No user consent/opt-in mechanism
4. Hardcoded tokens in code

### Important (Should Fix)
5. Missing event tracking: subscriptions, payments, coach interactions, errors
6. Inconsistent event naming across platforms
7. No event validation
8. Super properties not updated dynamically

### Nice to Have
9. No event schema documentation
10. No analytics dashboard
11. No error tracking integration
12. Debug mode too verbose in dev

---

## Quick Setup Guide

### For New Events (Mobile)
```javascript
import analytics from '../services/analytics';

// Track event
analytics.track('Event Name', {
  property1: value1,
  property2: value2,
});

// Set user properties
analytics.setUserProperties({
  custom_property: value,
});
```

### For New Events (Web)
```javascript
// In views with analytics controller
this.trackEvent('event_name', {
  property1: value1,
  property2: value2,
});
```

---

## Testing

**Debug Page:** `/public/mixpanel_debug.html`
- Test event tracking
- Test user identification
- Check configuration
- Test network connection
- Test batch events

---

## Platform Comparison

| Feature | Web | Mobile |
|---------|-----|--------|
| Mixpanel | Yes (EU) | Yes (US) |
| Google Analytics | Yes | No |
| Event Tracking | 30+ events | 20+ events |
| User Identification | Yes | Yes |
| Session Recording | 100% | Manual |
| Super Properties | Yes | Yes |
| Auto-capture | Yes | No |

---

## Next Steps Priority

1. [ ] Add Firebase Analytics to mobile
2. [ ] Configure mobile to use EU endpoint
3. [ ] Add user consent implementation
4. [ ] Move all tokens to environment variables
5. [ ] Document event schema
6. [ ] Add missing critical events
7. [ ] Standardize event naming
8. [ ] Create analytics dashboard
