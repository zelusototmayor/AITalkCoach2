# Analytics Documentation Index

This directory contains comprehensive documentation of the AI Talk Coach analytics setup.

## Quick Start

1. **New to the analytics setup?** Start with [ANALYTICS_QUICK_REFERENCE.md](./ANALYTICS_QUICK_REFERENCE.md)
2. **Need detailed technical info?** Read [ANALYTICS_REPORT.md](./ANALYTICS_REPORT.md)
3. **Looking for specific events?** Check [ANALYTICS_EVENT_REGISTRY.md](./ANALYTICS_EVENT_REGISTRY.md)

---

## Documentation Files

### ANALYTICS_REPORT.md (PRIMARY)
**Comprehensive technical analysis (500+ lines)**

Contains:
- Initialization details (Web & Mobile)
- Complete tracking implementation guide
- All 30+ events with properties and locations
- User property tracking strategy
- 12 critical and important issues identified
- 15 recommendations by priority
- File-by-file breakdown

**Best for:** In-depth understanding, architecture review, compliance assessment

---

### ANALYTICS_QUICK_REFERENCE.md
**Quick lookup guide (200 lines)**

Contains:
- Key file locations
- Event summary by category
- User properties list
- Issues summary
- Platform comparison table
- Quick setup examples

**Best for:** Quick lookups, getting started with new events, checklist reference

---

### ANALYTICS_EVENT_REGISTRY.md
**Complete event documentation (400+ lines)**

Contains:
- Every event with full details
- Exact file locations and line numbers
- All properties for each event
- Condition-based event documentation
- Super properties definition
- Event testing instructions

**Best for:** Event discovery, property validation, debugging

---

## Key Findings Summary

### Setup Status
- **Overall:** Functional but incomplete (65-70%)
- **Web:** Good coverage with GA + Mixpanel
- **Mobile:** Mixpanel only, EU endpoint missing

### What's Tracked (30+ events)
- Authentication flows (7 events)
- Recording & permissions (8 events)
- Session processing (8 events)
- Navigation/screens (3 events)
- Conversions (5+ events)
- App launch (1 event)

### Critical Issues (Must Fix)
1. Mobile missing Google Analytics
2. Mobile not using EU endpoint (GDPR issue)
3. No user consent mechanism
4. Hardcoded API tokens

### Important Issues (Should Fix)
5. Missing subscription/payment tracking
6. Inconsistent event naming
7. No event validation
8. Super properties not dynamic
9-12. Missing infrastructure (schema, dashboard, error tracking, validation)

---

## Core Files Reference

### Analytics Services
- `/mobile/services/analytics.js` - Mobile Mixpanel singleton (240+ lines)
- `/app/javascript/controllers/analytics_controller.js` - Web controller (500 lines)
- `/app/helpers/mixpanel_helper.rb` - Rails helper methods

### Initialization
- `/app/views/layouts/application.html.erb` - GA & Mixpanel setup (lines 13-53)
- `/mobile/App.js` - Mobile analytics init (lines 56-72)

### Integration Points
- `/mobile/context/AuthContext.js` - Auth events (7+ events)
- `/mobile/screens/practice/PracticeScreen.js` - Recording events (8+ events)
- `/mobile/screens/practice/SessionProcessingScreen.js` - Session events (8 events)
- `/app/javascript/controllers/recorder_controller.js` - Session completion

### Testing
- `/public/mixpanel_debug.html` - Debug/test page

---

## Event Categories

| Category | Count | Location |
|----------|-------|----------|
| Authentication | 7 | AuthContext.js, analytics_controller.js |
| Recording | 8 | PracticeScreen.js |
| Session Processing | 8 | SessionProcessingScreen.js |
| Navigation | 3 | App.js, analytics_controller.js |
| Conversion | 5+ | analytics_controller.js, recorder_controller.js |
| App Lifecycle | 1 | App.js |
| **TOTAL** | **30+** | - |

---

## Credentials Reference

| Platform | Type | ID/Token | Endpoint |
|----------|------|----------|----------|
| Web | Mixpanel | `44bf717b1ffcda5744f92721374b15da` | https://api-eu.mixpanel.com |
| Web | Google Analytics | `G-KM66Q2D5T3` | Google servers |
| Mobile | Mixpanel | `44bf717b1ffcda5744f92721374b15da` | Default (US) |
| Mobile | Google Analytics | NOT IMPLEMENTED | N/A |

---

## How to Add New Analytics

### For Mobile Events
```javascript
import analytics from '../services/analytics';

// Track event
analytics.track('Event Name', {
  property1: value1,
  property2: value2,
});

// Update user properties
analytics.setUserProperties({
  custom_property: value,
});
```

### For Web Events
```javascript
// In analytics_controller.js or via action binding
this.trackEvent('event_name', {
  property1: value1,
  property2: value2,
});
```

See ANALYTICS_QUICK_REFERENCE.md for more examples.

---

## Recommendations by Priority

### High Priority
1. Add Firebase Analytics to mobile
2. Fix mobile EU endpoint configuration
3. Implement user consent mechanism
4. Move tokens to environment variables
5. Standardize event naming
6. Add missing critical events

### Medium Priority
7. Document event schema
8. Implement error tracking
9. Update super properties dynamically
10. Add trial-to-customer tracking
11. Create monitoring dashboard
12. Add TypeScript types

### Low Priority
13. Reduce debug logging
14. Add event validation layer
15. Implement versioning strategy

---

## GDPR & Compliance Notes

**Current Status:** PARTIAL COMPLIANCE
- Web uses EU endpoint (compliant)
- Mobile uses US endpoint (non-compliant)
- No user consent mechanism (non-compliant)
- No opt-out option (non-compliant)

**To Achieve Compliance:**
1. Configure mobile for EU endpoint
2. Add consent banner/mechanism
3. Implement opt-out functionality
4. Document data processing practices

---

## Testing Analytics

Use the debug page at `/public/mixpanel_debug.html` to:
- Check Mixpanel configuration
- Test event tracking
- Test user identification
- Verify EU endpoint connectivity
- Test batch events
- Validate network connection

Or use browser console in dev mode for logging.

---

## Troubleshooting

**Events not appearing:**
- Check browser console for errors
- Verify analytics initialization
- Confirm user is identified (for authenticated users)
- Check Mixpanel token is correct

**Data routing to wrong endpoint:**
- Mobile: Must explicitly set `api_host: 'https://api-eu.mixpanel.com'`
- Web: Already configured correctly

**User properties not updating:**
- Call `analytics.setUserProperties()` after changes
- Verify user is identified first

---

## Contact & Updates

For questions about this analytics setup or to report issues:
1. Review the comprehensive documentation files
2. Check ANALYTICS_EVENT_REGISTRY.md for event details
3. See ANALYTICS_QUICK_REFERENCE.md for quick answers
4. Read ANALYTICS_REPORT.md for technical details

---

Last Updated: November 2025
Report Generated By: Comprehensive Analytics Audit
