# Complete Analytics Event Registry

## Authentication Events

### User Signed Up
- **Fired:** `mobile/context/AuthContext.js:175`, `app/javascript/controllers/analytics_controller.js:312`
- **Properties:** `user_id`, `email`, `name`, `method`, `signup_date`
- **User Properties Set:** `onboarding_completed: false`, `signup_date`
- **Platform:** Mobile + Web

### User Logged In
- **Fired:** `mobile/context/AuthContext.js:114`, `app/javascript/controllers/analytics_controller.js:122`
- **Properties:** `user_id`, `email`, `method`
- **Platform:** Mobile + Web

### Login Failed
- **Fired:** `mobile/context/AuthContext.js:123`
- **Properties:** `email`, `error`
- **Platform:** Mobile only

### Login Error
- **Fired:** `mobile/context/AuthContext.js:137`
- **Properties:** `email`, `error`
- **Platform:** Mobile only

### Signup Failed
- **Fired:** `mobile/context/AuthContext.js:185`
- **Properties:** `email`, `errors` (array)
- **Platform:** Mobile only

### Signup Error
- **Fired:** `mobile/context/AuthContext.js:199`
- **Properties:** `email`, `error`
- **Platform:** Mobile only

### User Logged Out
- **Fired:** `mobile/context/AuthContext.js:214`
- **Properties:** `user_id`
- **Side Effect:** Calls `analytics.reset()` to clear user identification
- **Platform:** Mobile only

### Onboarding Completed
- **Fired:** `mobile/context/AuthContext.js:311`
- **Properties:** `user_id`, `language`, `communication_style`, `age_range`
- **User Properties Set:** `onboarding_completed: true`, `onboarding_completion_date`, `preferred_language`
- **Platform:** Mobile only

---

## Navigation & Page Events

### Screen Viewed
- **Fired:** `mobile/App.js:39` (in navigation state handler)
- **Properties:** `screen_name`, `previous_screen`, route params
- **Frequency:** On every screen navigation
- **Platform:** Mobile only

### Landing Page View
- **Fired:** `app/javascript/controllers/analytics_controller.js:259`
- **Properties:** `event_category: 'engagement'`, `event_label: 'homepage'`
- **Platform:** Web only
- **Method:** Via `trackLandingPageView()` action handler

### Page View (Generic)
- **Fired:** `app/javascript/controllers/analytics_controller.js:225-255`
- **Properties:** `page_title`, `user_type`, optional `page_location`
- **GA:** Uses `gtag('config', 'G-KM66Q2D5T3', parameters)`
- **Mixpanel:** Uses `mixpanel.track_pageview()`
- **Platform:** Web only

---

## Recording & Microphone Events

### Recording Started
- **Fired:** `mobile/screens/practice/PracticeScreen.js:273`
- **Properties:**
  - `target_duration` (seconds)
  - `prompt_category` (string)
  - `prompt_text` (string)
  - `source` ('custom' or 'practice')
- **Platform:** Mobile only

### Recording Stopped
- **Fired:** `mobile/screens/practice/PracticeScreen.js:369`
- **Properties:** (not shown in code snippet)
- **Platform:** Mobile only

### Recording Error
- **Fired:** `mobile/screens/practice/PracticeScreen.js:407`
- **Properties:** `error` (error message)
- **Platform:** Mobile only

### Recording Start Failed
- **Fired:** `mobile/screens/practice/PracticeScreen.js:249`
- **Properties:** `reason` (e.g., 'permission_denied')
- **Platform:** Mobile only

### Microphone Permission Granted
- **Fired:** `mobile/screens/practice/PracticeScreen.js:93`
- **Properties:** None
- **Platform:** Mobile only

### Microphone Permission Denied
- **Fired:** `mobile/screens/practice/PracticeScreen.js:90`
- **Properties:** None
- **Platform:** Mobile only

### Microphone Permission Error
- **Fired:** `mobile/screens/practice/PracticeScreen.js:97`
- **Properties:** `error` (error message)
- **Platform:** Mobile only

---

## Prompt & Session Setup Events

### Prompt Shuffled
- **Fired:** `mobile/screens/practice/PracticeScreen.js:215`
- **Properties:** `new_prompt_category`
- **Condition:** Only when `canShuffle` is true
- **Platform:** Mobile only

### Time Duration Selected
- **Fired:** `mobile/screens/practice/PracticeScreen.js:428`
- **Properties:** `duration` (seconds)
- **Platform:** Mobile only

---

## Session Processing Events

### Session Processing Started
- **Fired:** `mobile/screens/practice/SessionProcessingScreen.js:31`
- **Properties:** `has_audio_file` (boolean), `initial_session_id`
- **Platform:** Mobile only

### Session Upload Started
- **Fired:** `mobile/screens/practice/SessionProcessingScreen.js:45`
- **Properties:** `target_duration` (seconds)
- **Platform:** Mobile only

### Session Upload Completed
- **Fired:** `mobile/screens/practice/SessionProcessingScreen.js:56`
- **Properties:** `session_id`, `upload_duration_ms`
- **Platform:** Mobile only

### Session Processing Progress
- **Fired:** `mobile/screens/practice/SessionProcessingScreen.js:78`
- **Properties:** `session_id`, `progress_percent`, `stage` (name)
- **Frequency:** Every 25% progress milestone (0%, 25%, 50%, 75%, 100%)
- **Platform:** Mobile only

### Session Relevance Failed
- **Fired:** `mobile/screens/practice/SessionProcessingScreen.js:95`
- **Properties:** `session_id`, `relevance_score`, `retake_count`
- **Platform:** Mobile only
- **Note:** Triggers navigation to SessionRelevance screen

### Session Incomplete
- **Fired:** `mobile/screens/practice/SessionProcessingScreen.js:111`
- **Properties:** `session_id`, `reason` (incomplete_reason), `duration_ms`
- **Platform:** Mobile only

### Session Processing Completed
- **Fired:** `mobile/screens/practice/SessionProcessingScreen.js:124`
- **Properties:** `session_id`, `total_duration_ms`, `final_progress`
- **Platform:** Mobile only

### Session Processing Failed
- **Fired:** `mobile/screens/practice/SessionProcessingScreen.js:139`
- **Properties:** `session_id`, `error`, `stage` (name), `progress_percent`
- **Platform:** Mobile only

---

## Trial Session Events (Web)

### Trial Started
- **Fired:** `app/javascript/controllers/analytics_controller.js:266`
- **Properties:** `event_category: 'conversion'`, `event_label: source`, `value: 1`
- **Handler:** `handleTrialClick(event)` action binding
- **Platform:** Web only

### Trial Completed
- **Fired:** `app/javascript/controllers/analytics_controller.js:287`
- **Web Handler:** Called from analytics_controller.js
- **Mobile Handler:** Called from `recorder_controller.js:1331`
- **Properties:**
  - `event_category: 'conversion'`
  - `event_label: 'trial_recording_completed'`
  - `value: 1`
  - `session_duration` (optional, in seconds)
  - `target_duration` (optional, in seconds)
- **Platform:** Web + Mobile (called from recorder)

### Trial Analysis View
- **Fired:** `app/javascript/controllers/analytics_controller.js:301`
- **Properties:**
  - `event_category: 'engagement'`
  - `event_label: 'trial_results_viewed'`
  - `wpm` (words per minute, optional)
  - `filler_count` (optional)
- **Data Extraction:** From page elements with `data-trial-*` attributes
- **Platform:** Web only

---

## Real Session Events (Web)

### Real Session Started
- **Fired:** `app/javascript/controllers/analytics_controller.js:340`
- **Properties:**
  - `event_category: 'engagement'`
  - `event_label: 'authenticated_session_started'`
  - `value: 1`
  - `target_duration` (optional)
  - `prompt_category` (optional)
- **Platform:** Web only

### Real Session Completed
- **Fired:** `app/javascript/controllers/analytics_controller.js:357`
- **Web Handler:** Called from analytics_controller.js
- **Mobile Handler:** Called from `recorder_controller.js:1339`
- **Properties:**
  - `event_category: 'engagement'`
  - `event_label: 'authenticated_session_completed'`
  - `value: 2`
  - `session_duration` (optional, in seconds)
  - `target_duration` (optional, in seconds)
  - `session_id` (optional)
- **Platform:** Web only (but mobile calls through recorder)

### Real Analysis View
- **Fired:** `app/javascript/controllers/analytics_controller.js:372`
- **Properties:**
  - `event_category: 'engagement'`
  - `event_label: 'authenticated_analysis_viewed'`
  - `wpm` (optional)
  - `clarity_score` (optional)
  - `filler_rate` (optional)
- **Data Extraction:** From page elements with `data-metric-*` attributes
- **Platform:** Web only

---

## Conversion/Signup Events (Web)

### Signup Clicked
- **Fired:** `app/javascript/controllers/analytics_controller.js:305`
- **Properties:**
  - `event_category: 'conversion'`
  - `event_label: source` (e.g., 'navigation', 'landing_page')
  - `value: 1`
- **Handler:** `handleSignupClick(event)` action binding
- **Platform:** Web only

### Signup Completed
- **Fired:** `app/javascript/controllers/analytics_controller.js:323`
- **Auto-Detection:** Via `checkSignupCompletion()` (lines 400-417)
- **Trigger:** Detects "Account created successfully" flash message
- **Properties:**
  - `event_category: 'conversion'`
  - `event_label: 'registration_completed'`
  - `value: 10` (higher value for conversions)
  - `user_id` (optional)
- **Platform:** Web only

---

## App Launch Event

### App Launched
- **Fired:** `mobile/App.js:66` (on first useEffect)
- **Properties:** `launch_time` (ISO timestamp)
- **Frequency:** Once per app session
- **Platform:** Mobile only

---

## User Identification Events

### User Identified
- **Fired:** Various locations (Auth, Signup)
- **Mobile:** `mobile/context/AuthContext.js:108`, `168`
- **Web:** `app/javascript/controllers/analytics_controller.js:94`
- **Method:** `analytics.identify(userId, traits)`
- **Traits:**
  - `name`: User's display name
  - `email`: User's email address
  - `onboarding_completed`: Boolean
  - `signup_date`: ISO timestamp (signup only)

---

## Event Timing & Scope

### Minimal Properties (No Details)
- Microphone Permission Granted
- Microphone Permission Denied
- User Logged Out

### Standard Properties (3-5 fields)
- User Signed Up/Logged In
- Recording Started
- Session Processing Started

### Rich Properties (5+ fields)
- Session Processing Progress
- Session Processing Completed
- Session Processing Failed
- Real Session Completed

### Custom Metrics Properties
- Trial Analysis View (WPM, filler count)
- Real Analysis View (WPM, clarity score, filler rate)

---

## Super Properties (Context Data)

### Mobile Super Properties
Set once at initialization:
- `platform`: 'ios' or 'android'
- `app_version`: From Expo config (e.g., '1.0.0')
- `device_model`: Device name
- `os_version`: OS version number

### Web Super Properties
- `User Type`: 'authenticated', 'trial', or 'anonymous'
- `Environment`: 'production' or 'development'
- `Platform`: 'Web'
- `Page URL`: window.location.href
- `Page Title`: document.title

**Note:** Web super properties are set per event (not persistent)

---

## Conditional Events

Events that fire based on certain conditions:

| Event | Condition | Location |
|-------|-----------|----------|
| Session Relevance Failed | session.processing_state === 'relevance_failed' | SessionProcessingScreen.js:93 |
| Session Incomplete | !fullSession.completed && incomplete_reason | SessionProcessingScreen.js:109 |
| Prompt Shuffled | canShuffle && shuffle successful | PracticeScreen.js:214 |
| Recording Start Failed | status !== 'granted' | PracticeScreen.js:249 |
| Trial Started | User clicks trial button | analytics_controller.js:266 |
| Signup Completed | Auto-detected from flash message | analytics_controller.js:406 |

---

## Event Validation Notes

### Missing Validation
- No check that required properties are present
- No type validation for properties
- No range checks for numeric values

### Known Issues
- Some properties may be null/undefined
- Event names have inconsistent formatting across platforms
- Trial user properties not tracked after conversion

---

## Testing the Events

Use the debug page at `/public/mixpanel_debug.html` to:
1. Check configuration
2. Test basic event tracking
3. Test user identification
4. Test batch events
5. Verify network connection to Mixpanel EU endpoint

Or check browser console logs in development mode for event firing.

