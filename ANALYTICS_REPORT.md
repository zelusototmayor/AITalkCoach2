# AI Talk Coach Analytics Setup - Comprehensive Report

## Executive Summary
The AI Talk Coach application has **both Google Analytics and Mixpanel** integrated across web and mobile platforms. The setup appears functional but with some configuration and implementation gaps that should be addressed.

---

## 1. ANALYTICS INITIALIZATION

### 1.1 Web (Rails Application)
**Location:** `/app/views/layouts/application.html.erb` (lines 13-53)

**Google Analytics:**
- Measurement ID: `G-KM66Q2D5T3`
- Loaded via Google Tag Manager (gtag.js)
- Initialization: Lines 13-21
- Status: ACTIVE

**Mixpanel (Web):**
- Token: `44bf717b1ffcda5744f92721374b15da`
- Environment-based configuration (respects ENV['MIXPANEL_TOKEN'])
- API Host: `https://api-eu.mixpanel.com` (EU endpoint)
- Debug mode: Enabled in non-production environments
- Auto-capture: Enabled
- Session recording: 100% of sessions
- Initialization: Lines 23-53
- Status: ACTIVE

### 1.2 Mobile (React Native/Expo)
**Location:** `/mobile/App.js` (lines 56-72)

**Mixpanel (Mobile):**
- Token: `44bf717b1ffcda5744f92721374b15da` (same as web)
- Uses `mixpanel-react-native` library (v3.1.2)
- Debug logging enabled in development (__DEV__)
- Automatic events: Disabled (manual tracking only)
- Native integration: Disabled (Expo compatibility)
- Initialization: Async initialization on app launch
- Status: ACTIVE
- Super properties registered: Platform, app version, device model, OS version

**Google Analytics:**
- NOT directly implemented in mobile app
- Only Mixpanel is used on mobile

---

## 2. INITIALIZATION POINTS

### Web Analytics Controller
**File:** `/app/javascript/controllers/analytics_controller.js`

Key initialization details:
- Waits for Mixpanel library to load (lines 32-40)
- Registers super properties (lines 69-76):
  - User Type
  - Environment
  - Platform: 'Web'
  - Page URL
  - Page Title

- User identification (lines 82-130):
  - Identifies user by ID from data attributes
  - Sets user properties: $email, $name, $created, User Type
  - Handles user switching with reset logic

- GA Configuration ID: `G-KM66Q2D5T3` (line 241)

### Mobile Analytics Service
**File:** `/mobile/services/analytics.js`

Singleton service with methods:
- `init(token)`: Initializes Mixpanel with token and super properties
- `identify(userId, traits)`: Identifies user and sets people properties
- `track(eventName, properties)`: Tracks events with timestamp enrichment
- `trackScreen(screenName, properties)`: Convenience method for screen views
- `setUserProperties(properties)`: Updates user properties
- `incrementProperty(property, value)`: Increments numeric properties
- `timeEvent(eventName)`: Starts event timing
- `reset()`: Clears user identification on logout

---

## 3. TRACKED EVENTS

### 3.1 Authentication Events (Mobile & Web)

**User Signed Up:**
- Properties: user_id, email, name, method, signup_date
- Fired in: `AuthContext.js` line 175
- Also tracked on web: `analytics_controller.js` line 312

**User Logged In:**
- Properties: user_id, email, method
- Fired in: `AuthContext.js` line 114
- Also tracked on web: `analytics_controller.js` line 122

**Login Failed:**
- Properties: email, error
- Fired in: `AuthContext.js` line 123

**Login Error:**
- Properties: email, error
- Fired in: `AuthContext.js` line 137

**Signup Failed:**
- Properties: email, errors
- Fired in: `AuthContext.js` line 185

**Signup Error:**
- Properties: email, error
- Fired in: `AuthContext.js` line 199

**User Logged Out:**
- Properties: user_id
- Fired in: `AuthContext.js` line 214

### 3.2 Onboarding Events (Mobile)

**Onboarding Completed:**
- Properties: user_id, language, communication_style, age_range
- Fired in: `AuthContext.js` line 311
- Also sets user properties: onboarding_completed, onboarding_completion_date, preferred_language

### 3.3 Navigation/Screen Events

**Screen Viewed:**
- Mobile: `analytics.trackScreen()` in navigation handler (`App.js` line 39)
- Properties: screen_name, previous_screen, route params
- Screens tracked: Practice, and any route changes

**Landing Page View:**
- Web: Specific handler in `analytics_controller.js` line 259

### 3.4 Practice/Recording Events (Mobile)

**Recording Started:**
- Properties: target_duration, prompt_category, prompt_text, source
- Fired in: `PracticeScreen.js` line 273

**Recording Stopped:**
- Fired in: `PracticeScreen.js` line 369
- (Details not shown in truncated content)

**Recording Error:**
- Properties: error message
- Fired in: `PracticeScreen.js` line 407

**Recording Start Failed:**
- Properties: reason
- Fired in: `PracticeScreen.js` line 249

**Microphone Permission Granted:**
- Fired in: `PracticeScreen.js` line 93

**Microphone Permission Denied:**
- Fired in: `PracticeScreen.js` line 90

**Microphone Permission Error:**
- Properties: error
- Fired in: `PracticeScreen.js` line 97

**Prompt Shuffled:**
- Properties: new_prompt_category
- Fired in: `PracticeScreen.js` line 215

**Time Duration Selected:**
- Properties: duration
- Fired in: `PracticeScreen.js` line 428

### 3.5 Session Processing Events (Mobile)

**Session Processing Started:**
- Properties: has_audio_file, initial_session_id
- Fired in: `SessionProcessingScreen.js` line 31

**Session Upload Started:**
- Properties: target_duration
- Fired in: `SessionProcessingScreen.js` line 45

**Session Upload Completed:**
- Properties: session_id, upload_duration_ms
- Fired in: `SessionProcessingScreen.js` line 56

**Session Processing Progress:**
- Properties: session_id, progress_percent, stage
- Fired every 25% progress in: `SessionProcessingScreen.js` line 78

**Session Relevance Failed:**
- Properties: session_id, relevance_score, retake_count
- Fired in: `SessionProcessingScreen.js` line 95

**Session Incomplete:**
- Properties: session_id, reason, duration_ms
- Fired in: `SessionProcessingScreen.js` line 111

**Session Processing Completed:**
- Properties: session_id, total_duration_ms, final_progress
- Fired in: `SessionProcessingScreen.js` line 124

**Session Processing Failed:**
- Properties: session_id, error, stage, progress_percent
- Fired in: `SessionProcessingScreen.js` line 139

### 3.6 Trial Session Events (Web)

**Trial Started:**
- Properties: event_category, event_label (source), value
- Fired in: `analytics_controller.js` line 266

**Trial Completed:**
- Properties: event_category, event_label, value, session_duration, target_duration
- Fired in: `analytics_controller.js` line 287 & `recorder_controller.js` line 1331

**Trial Analysis View:**
- Properties: event_category, event_label, wpm, filler_count
- Fired in: `analytics_controller.js` line 301

### 3.7 Real Session Events (Web)

**Real Session Started:**
- Properties: event_category, event_label, value, target_duration, prompt_category
- Fired in: `analytics_controller.js` line 340

**Real Session Completed:**
- Properties: event_category, event_label, value, session_duration, target_duration, session_id
- Fired in: `analytics_controller.js` line 357 & `recorder_controller.js` line 1339

**Real Analysis View:**
- Properties: event_category, event_label, wpm, clarity_score, filler_rate
- Fired in: `analytics_controller.js` line 373

### 3.8 Signup/Conversion Events (Web)

**Signup Clicked:**
- Properties: event_category, event_label (source), value
- Fired in: `analytics_controller.js` line 305

**Signup Completed:**
- Properties: event_category, event_label, value (10), user_id
- Fired in: `analytics_controller.js` line 323

### 3.9 App Launch Event (Mobile)

**App Launched:**
- Properties: launch_time (ISO timestamp)
- Fired in: `App.js` line 66

---

## 4. USER PROPERTY TRACKING

### Mobile (Mixpanel)
**Super Properties (sent with every event):**
- platform: 'ios' or 'android'
- app_version: From Expo config
- device_model: Device name
- os_version: OS version

**User Properties (Mixpanel People):**
- $name: User's name
- $email: User's email
- $created: Account creation timestamp
- onboarding_completed: Boolean
- preferred_language: User's selected language
- communication_style: From onboarding
- age_range: From onboarding

### Web (Mixpanel & GA)
**Super Properties:**
- User Type: 'authenticated', 'trial', or 'anonymous'
- Environment: 'production' or 'development'
- Platform: 'Web'
- Page URL: Current page URL
- Page Title: Document title

**User Properties (Mixpanel People):**
- $email: User's email
- $name: User's name
- $created: Account creation timestamp
- User Type: 'authenticated'
- Platform: 'Web'

**GA Properties (from gtag config):**
- user_type: Determined from page state
- page_title: Document title
- page_location: Current URL
- timestamp: ISO timestamp

---

## 5. TRACKING IMPLEMENTATION DETAILS

### Event Enrichment
All events are enriched with:
- **Timestamp:** Added by analytics service automatically (ISO format)
- **User Context:** User type, user ID (when authenticated)
- **Page Context:** Page title, page URL (web only)
- **Device Context:** Platform, device model, OS version (mobile only)

### Event Name Formatting
**Mobile:** Snake_case format used by Mixpanel (e.g., 'User Logged In')
**Web:** 
- GA: Snake_case (e.g., 'user_logged_in')
- Mixpanel: Title Case (automatically converted from snake_case in `analytics_controller.js` line 204-209)

### Session Tracking
- **GA:** Uses GA's built-in session tracking
- **Mixpanel:** 
  - Web: Auto-enabled (record_sessions_percent: 100)
  - Mobile: Manual tracking (no automatic session recording)

### User Identification Flow
1. User logs in/signs up
2. `analytics.identify(userId, traits)` called
3. Mixpanel/GA associates subsequent events with user ID
4. On logout: `analytics.reset()` clears identification

---

## 6. ISSUES & CONFIGURATION GAPS

### Critical Issues

1. **Google Analytics NOT on Mobile**
   - Mobile app only uses Mixpanel, no GA integration
   - Consider adding Firebase Analytics for mobile GA support
   - Issue: Inconsistent analytics across platforms

2. **API Endpoint Discrepancy**
   - Web: Uses EU endpoint (`https://api-eu.mixpanel.com`)
   - Mobile: Uses default US endpoint (not specified, uses library default)
   - Issue: Different data centers, compliance implications

3. **Missing Event Tracking in Critical Flows**
   - No tracking for password reset flows
   - No tracking for subscription/payment events
   - No tracking for session retakes/re-attempts
   - No tracking for coach interaction/recommendations
   - No tracking for blog/content consumption
   - No tracking for error/crash events (beyond recording errors)

4. **Inconsistent Event Naming**
   - Web uses snake_case initially, converted to Title Case for Mixpanel
   - Mobile uses Title Case directly
   - Could lead to event name mismatches between platforms
   - Recommendation: Standardize on one format

5. **Missing Property Validation**
   - No validation that required properties are included
   - No error handling for null/undefined property values
   - Some events track optional properties that may be null

### Configuration Issues

6. **Token Management**
   - Token hardcoded in multiple files (security concern)
   - Should use environment variables exclusively
   - Mobile has TODO comment about setting token from env

7. **Debug Mode Always Enabled in Dev**
   - May leak sensitive user data in logs
   - Consider more granular debug levels

8. **EU Endpoint Not Used on Mobile**
   - Web explicitly uses EU endpoint for GDPR compliance
   - Mobile doesn't specify, may route to US servers
   - Issue: GDPR/Privacy compliance gap

9. **Missing Opt-In/Opt-Out**
   - No user consent mechanism for analytics tracking
   - No ability to disable analytics per user preference
   - Issue: Potential GDPR/privacy violations

10. **No Analytics for Trial Users (Web)**
    - Trial mode tracking exists but doesn't track user properties
    - Can't identify trial users later if they convert

11. **Super Properties Not Updated on User Changes**
    - User Type super property set once at initialization
    - Not updated if user logs in/out during session
    - Web: Could show stale user type for long sessions

### Missing Infrastructure

12. **No Analytics Dashboard/Monitoring**
    - No code to expose events for monitoring/debugging
    - Debug test page exists but not production monitoring

13. **No Event Schema Definition**
    - No documentation of required vs optional properties
    - No type definitions for events
    - Event discovery would require code inspection

14. **No Error Tracking**
    - No integration with error tracking service
    - Mixpanel errors logged but not tracked as events

---

## 7. PROPERLY IMPLEMENTED FEATURES

### Strengths
1. ✓ Mixpanel singleton pattern properly implemented on mobile
2. ✓ User identification with proper reset on logout
3. ✓ Screen view tracking in navigation (mobile)
4. ✓ Event enrichment with timestamps
5. ✓ Error handling in analytics initialization
6. ✓ Conditional initialization based on environment
7. ✓ Super properties registered for context
8. ✓ User session completion tracking with metrics
9. ✓ Processing progress milestone tracking
10. ✓ Both GA and Mixpanel integrated on web

---

## 8. TRACKING UTILITIES & HELPERS

### Available Methods

**Mobile (`analytics.js`):**
- `init(token)` - Initialize analytics
- `identify(userId, traits)` - Set user identity
- `track(eventName, properties)` - Track event
- `trackScreen(screenName, properties)` - Track screen view
- `setUserProperties(properties)` - Update user properties
- `incrementProperty(property, value)` - Increment numeric property
- `timeEvent(eventName)` - Start event timing
- `getDistinctId()` - Get current user ID
- `reset()` - Clear user identification
- `registerSuperProperties(properties)` - Set context properties

**Web (`analytics_controller.js`):**
- `trackEvent(eventName, parameters)` - Core tracking method
- `trackPageView(pagePath)` - Track page view
- `trackLandingPageView()` - Track landing page
- `trackTrialStarted(source)` - Track trial initiation
- `trackTrialCompleted(duration, target)` - Track trial completion
- `trackTrialAnalysisView(analysisData)` - Track results view
- `trackSignupClicked(source)` - Track signup button
- `trackSignupCompleted(userId)` - Track signup completion
- `trackRealSessionStarted(sessionData)` - Track authenticated session start
- `trackRealSessionCompleted(sessionData)` - Track session completion
- `trackRealAnalysisView(sessionData)` - Track analysis view
- `identifyUser(userId, email, name)` - Set user identity
- `checkSignupCompletion()` - Auto-detect signup completion

**Web Helper (`mixpanel_helper.rb`):**
- `mixpanel_identify_user` - Server-side user identification
- `mixpanel_track_page_view(page_name)` - Server-side page tracking
- `mixpanel_set_super_properties` - Register super properties

---

## 9. TOKEN & API ENDPOINT SUMMARY

| Platform | Type | Token | Endpoint | Config |
|----------|------|-------|----------|--------|
| Web | Mixpanel | `44bf717b1ffcda5744f92721374b15da` | `https://api-eu.mixpanel.com` | ENV-based |
| Web | Google Analytics | `G-KM66Q2D5T3` | Google servers | Hardcoded |
| Mobile | Mixpanel | `44bf717b1ffcda5744f92721374b15da` | Default (likely US) | Hardcoded with TODO |
| Mobile | Google Analytics | NONE | N/A | NOT IMPLEMENTED |

---

## 10. RECOMMENDATIONS

### High Priority
1. **Add GA to Mobile** - Use Firebase Analytics for consistency
2. **Fix EU Endpoint on Mobile** - Explicitly set `api_host` to EU server for GDPR
3. **Add User Consent** - Implement opt-in/opt-out mechanism
4. **Move Token to Env Variables** - Remove hardcoded tokens
5. **Standardize Event Naming** - Use consistent format across platforms
6. **Add Missing Event Tracking** - Subscription, payment, coach interactions, errors

### Medium Priority
7. Add event schema documentation
8. Implement proper error tracking/reporting
9. Update super properties dynamically
10. Add trial-to-customer tracking
11. Create analytics monitoring dashboard
12. Add TypeScript types for events

### Low Priority
13. Reduce debug logging in production
14. Add event validation layer
15. Implement analytics versioning strategy

---

## 11. FILES INVOLVED

### Core Analytics Files
- `/mobile/services/analytics.js` - Mobile analytics singleton
- `/app/javascript/controllers/analytics_controller.js` - Web analytics controller
- `/app/helpers/mixpanel_helper.rb` - Rails helper methods
- `/app/views/layouts/application.html.erb` - GA/Mixpanel initialization
- `/public/mixpanel_debug.html` - Debug testing page

### Integration Points
- `/mobile/App.js` - Mobile analytics initialization
- `/mobile/context/AuthContext.js` - Mobile auth event tracking
- `/mobile/screens/practice/PracticeScreen.js` - Recording event tracking
- `/mobile/screens/practice/SessionProcessingScreen.js` - Session tracking
- `/app/javascript/controllers/recorder_controller.js` - Session completion tracking

### Related Configuration
- `/mobile/package.json` - Lists mixpanel-react-native v3.1.2
- `/config/routes.rb` - Would need to enable if using pwa_manifest
- Environment files - Should contain MIXPANEL_TOKEN

---

## Summary

The analytics setup is **functional but incomplete**:
- Web platform has good Mixpanel + Google Analytics coverage
- Mobile platform has Mixpanel but missing Google Analytics
- Key user flows are tracked (auth, sessions, onboarding)
- Critical issues exist with GDPR compliance, token management, and platform parity
- Event naming and property standards need improvement
- Several important user interactions are not tracked

Estimated completeness: **65-70%**
