# Mobile App - Onboarding Flow Implementation

## Overview
9-screen onboarding experience that introduces the app, collects user preferences, provides a trial recording, and ends with a paywall offering the "practice daily = free forever" model.

---

## Screen Flow

### Screen 1: Welcome/Loading
**Purpose:** Brand introduction with animated visual

**Components:**
- "WELCOME" heading
- Animated sound wave bars (moving back and forth)
- "AI TALK COACH" text below
- Auto-advance after 2-3 seconds

**Technical:**
- Simple animation using `Animated.View` or Lottie
- `useEffect` with 2-3s timer → navigate to next screen
- No user interaction required

---

### Screen 2: Value Proposition
**Purpose:** Establish why communication is the #1 skill

**Components:**
- Header: "Master the #1 skill that opens every door"
- 4 benefit cards in 2x2 grid:
  1. Social Impact - "Build deeper relationships"
  2. Workplace Impact - "Advance your career faster"
  3. Confidence - "Feel confident in any room"
  4. Leadership - "Inspire and influence others"
- Forward arrow/button to continue

**Technical:**
- Static cards with icons
- Manual navigation (user taps to continue)

---

### Screen 3: Speaking Goals
**Purpose:** Collect user's improvement goals (multi-select)

**Components:**
- Header: "What are your speaking goals?"
- 8 selectable cards:
  1. Public Speaking
  2. Acing Interviews
  3. Sales & Pitching
  4. Podcasting/Content Creation
  5. Social Skills
  6. Acting/Performance
  7. Leadership/Management
  8. Other
- Continue button (enabled when at least 1 selected)

**Technical:**
- Multi-select state array
- Cards highlight when selected (border + background color)
- Store selections in OnboardingContext

---

### Screen 4: Motivation
**Purpose:** Personalized encouragement based on selected goals

**Components:**
- Header: "You're Not Alone"
- Personalized tip card (based on goal selection):
  - Public Speaking → "78% of people fear public speaking more than death"
  - Interviews → "90% of interview success is preparation + delivery"
  - Sales → "Top salespeople practice their pitch 10+ times"
  - Default → "Great communicators aren't born, they're built"
- Generic stat card: "Even 1% improvement compounds over time"
- Continue button

**Technical:**
- Conditional content based on OnboardingContext.goals
- Simple card layout

---

### Screen 5: User Profile
**Purpose:** Collect demographic and preference data

**Components:**
- Header: "Tell us about yourself"
- **Communication Style** (single select):
  - Introvert
  - Extrovert
  - Ambivert
  - Not sure
- **Age Range** (dropdown or horizontal picker):
  - 18-24
  - 25-34
  - 35-44
  - 45-54
  - 55+
- **Language** (dropdown):
  - English
  - Spanish
  - French
  - German
  - Portuguese
  - Other
- Continue button

**Technical:**
- Form state management
- Store in OnboardingContext
- Picker/Dropdown components (React Native Picker or custom)

---

### Screen 6: Trial Recording (30 seconds)
**Purpose:** Let user experience the core feature

**Components:**
- Header: "Let's do a 30-second trail"
- Prompt card (choose one - use best judgment):
  - **Option 1 (Recommended):** "What did you enjoy most about last week and why?"
    - Relatable, recent memory, easier to express
  - **Option 2:** "What led you to try AI Talk Coach and why?"
    - Reinforces their motivation, may increase conversions
- Timer: "0s / 30s" (positioned on the right)
- Large circular record button (tap to start/stop):
  - **UI Design (similar to web app):**
    - Circular border that progressively fills (0% → 100%) as recording advances
    - Timer shows on the right side
    - **No waveform visualization while recording** (just the filling circle)
  - **States:**
    - Ready: "Tap to Record" text inside circle
    - Recording: Circle border fills clockwise (like a progress ring), timer counts
    - Processing: Show spinner "Analyzing your speech..."
- **Cancel button** (visible during recording): "Cancel" - allows user to restart
- Skip button (top-right)

**Technical:**
- **Audio recording:** `expo-av` Audio.Recording
- **Backend integration:** Upload to Rails API (same as trial session endpoint)
- **Recording flow:**
  1. User taps circle → Recording starts
  2. Circle border animates (fills 0% → 100% over 30s)
  3. Timer counts up: "0s / 30s" → "30s / 30s"
  4. User can tap "Cancel" to restart
  5. At 30s (or manual stop): Recording stops
  6. **Automatically upload and start processing** (no extra button needed)
  7. Show "Analyzing..." spinner while processing
- **States:**
  - Idle: "Tap to Record"
  - Recording: Filling circle animation + timer
  - Processing: Spinner "Analyzing your speech..."
- **Navigation:** Auto-advance to results when processing completes
- **Skip:** Jump directly to results with **mock data disclaimer**

**Backend API:**
- Use existing trial session logic from web app
- Endpoints needed:
  - `POST /api/v1/trial_sessions` → Create session, return token
  - `POST /api/v1/trial_sessions/:token/upload` → Upload audio
  - `GET /api/v1/trial_sessions/:token/status` → Check processing status
  - `GET /api/v1/trial_sessions/:token` → Get results

---

### Screen 7: Results + Upsell
**Purpose:** Show trial results and tease premium features

**Components:**
- Header: "Great job! Let's see how you did"
- **Mock Data Disclaimer (if user skipped):**
  - Small badge/text at top: "This is example data - record your own to see real results!"
  - Different styling (e.g., lighter background or dashed border) to indicate mock data
- **3 Key Metrics (cards):**
  - Clarity: 72% (with icon)
  - Filler words: 8.5/min (with icon)
  - Pace: 145 WPM (with icon)
- **Expandable section:** "See Full Transcript" (accordion)
- **Unlock section:** "What You'll Unlock"
  - AI Coach Recommendations
  - Advanced Metrics (pitch, energy, pauses)
  - Custom Improvement Plan
  - Progress Tracking
- **CTA button:** "Get Full Access →"

**Technical:**
- **If user recorded:** Fetch real results from trial session API
- **If user skipped:**
  - Use mock data
  - Show clear disclaimer banner: "This is example data"
  - Maybe use different card style (dashed border, muted colors)
- Expandable transcript (useState toggle)
- Navigate to cinematic screen on CTA tap

**Mock Data Structure:**
```javascript
{
  isMockData: true, // Flag to show disclaimer
  clarity: 72,
  fillerWordsPerMinute: 8.5,
  wordsPerMinute: 145,
  transcript: "Well, um, my biggest achievement was when I, uh, led a team of 5 people..."
}
```

---

### Screen 8: Cinematic Transition
**Purpose:** Build emotional connection before paywall

**Components:**
- Centered text with fade in/out animations:
  1. "We want you to improve as much as you do!" (fade in → hold 2s → fade out)
  2. "So we reward consistency" (fade in → hold 2s → fade out)
  3. "Practice every day, and the app is FREE FOREVER" (fade in → hold 2s)
- Auto-advance to paywall after final message

**Technical:**
- `Animated.timing` with opacity transitions
- Chained animations using `Animated.sequence`
- No user interaction (except maybe skip button)

---

### Screen 9: Paywall
**Purpose:** Introduce pricing and "practice daily = free" model

**Components:**
- Header: "Practice daily, use free forever"
- **How It Works card:**
  - Icon + text explaining:
    - "Complete a 1-minute session every day"
    - "Your free access extends by 24 hours"
    - "Stop practicing? Subscription kicks in"
- **Pricing options (2 cards, selectable):**
  - **Monthly:** $9.99/month
  - **Yearly:** $60/year (Save 50%!)
  - Badge: "Only charged if you miss a day"
- **Payment button:** "Add Payment and Start"
  - For now: Just shows Stripe placeholder (doesn't charge)
- **Skip button (bottom):** "Skip for now" → Go to main app
- **Fine print:** "Cancel anytime. No charges if you practice daily."

**Technical:**
- Card selection (highlight selected plan)
- Stripe integration placeholder:
  - Comment where Stripe key goes
  - Mock payment flow (show success message)
- Skip button bypasses payment, goes to main app
- Store selected plan in OnboardingContext
- Navigate to main app home screen

**Later: Stripe/RevenueCat Integration**
- Use Stripe Checkout or RevenueCat for subscriptions
- Store payment method, but don't charge
- Backend tracks daily practice streak
- Charge only if user misses a day

---

## Technical Architecture

### Project Structure
```
mobile/
├── App.js
├── navigation/
│   ├── OnboardingNavigator.js      # Stack navigator for onboarding
│   └── RootNavigator.js            # Main app navigator (after onboarding)
├── screens/
│   ├── onboarding/
│   │   ├── WelcomeScreen.js
│   │   ├── ValuePropScreen.js
│   │   ├── GoalsScreen.js
│   │   ├── MotivationScreen.js
│   │   ├── ProfileScreen.js
│   │   ├── TrialRecordingScreen.js
│   │   ├── ResultsScreen.js
│   │   ├── CinematicScreen.js
│   │   └── PaywallScreen.js
│   └── main/
│       └── HomeScreen.js           # Placeholder main app screen
├── components/
│   ├── WaveAnimation.js
│   ├── MetricCard.js
│   ├── GoalCard.js
│   ├── PricingCard.js
│   └── Button.js                   # Reusable button component
├── context/
│   └── OnboardingContext.js        # Store user selections
├── services/
│   └── api.js                      # API client for Rails backend
├── constants/
│   ├── colors.js
│   ├── spacing.js
│   └── onboardingData.js           # Static content (goals, prompts, etc.)
└── package.json
```

### State Management: OnboardingContext

```javascript
// context/OnboardingContext.js
const OnboardingContext = createContext();

export const OnboardingProvider = ({ children }) => {
  const [onboardingData, setOnboardingData] = useState({
    goals: [],                  // Array of selected goal strings
    communicationStyle: null,   // "introvert" | "extrovert" | "ambivert" | "not_sure"
    ageRange: null,            // "18-24" | "25-34" | etc.
    language: "en",            // Language code
    trialSessionToken: null,   // Token from trial recording
    trialResults: null,        // Results from trial session
    selectedPlan: null,        // "monthly" | "yearly"
  });

  return (
    <OnboardingContext.Provider value={{ onboardingData, setOnboardingData }}>
      {children}
    </OnboardingContext.Provider>
  );
};
```

### API Service

```javascript
// services/api.js
const API_BASE_URL = 'https://app.aitalkcoach.com/api/v1'; // or localhost for dev

export const api = {
  // Trial session endpoints
  createTrialSession: async (title, language) => {
    const response = await fetch(`${API_BASE_URL}/trial_sessions`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ title, language }),
    });
    return response.json();
  },

  uploadTrialAudio: async (token, audioUri) => {
    const formData = new FormData();
    formData.append('audio', {
      uri: audioUri,
      type: 'audio/wav',
      name: 'recording.wav',
    });

    await fetch(`${API_BASE_URL}/trial_sessions/${token}/upload`, {
      method: 'POST',
      body: formData,
    });
  },

  getTrialStatus: async (token) => {
    const response = await fetch(`${API_BASE_URL}/trial_sessions/${token}/status`);
    return response.json();
  },

  getTrialResults: async (token) => {
    const response = await fetch(`${API_BASE_URL}/trial_sessions/${token}`);
    return response.json();
  },
};
```

### Navigation Flow

```javascript
// navigation/OnboardingNavigator.js
import { createStackNavigator } from '@react-navigation/stack';

const Stack = createStackNavigator();

export default function OnboardingNavigator() {
  return (
    <Stack.Navigator screenOptions={{ headerShown: false }}>
      <Stack.Screen name="Welcome" component={WelcomeScreen} />
      <Stack.Screen name="ValueProp" component={ValuePropScreen} />
      <Stack.Screen name="Goals" component={GoalsScreen} />
      <Stack.Screen name="Motivation" component={MotivationScreen} />
      <Stack.Screen name="Profile" component={ProfileScreen} />
      <Stack.Screen name="TrialRecording" component={TrialRecordingScreen} />
      <Stack.Screen name="Results" component={ResultsScreen} />
      <Stack.Screen name="Cinematic" component={CinematicScreen} />
      <Stack.Screen name="Paywall" component={PaywallScreen} />
    </Stack.Navigator>
  );
}
```

---

## Data to Collect During Onboarding

**Stored in OnboardingContext:**
1. Selected goals (array)
2. Communication style
3. Age range
4. Preferred language
5. Trial session token (if recorded)
6. Trial results (metrics + transcript)
7. Selected pricing plan

**Sent to Backend After Onboarding:**
- When user completes onboarding (or skips paywall), send profile data to backend
- Create user account or update trial session with preferences
- Backend can use this data for personalization

---

## Styling Guidelines

**Colors:**
- Primary: #4F46E5 (Indigo)
- Secondary: #10B981 (Green)
- Background: #FFFFFF
- Card background: #F9FAFB
- Text: #111827
- Text secondary: #6B7280
- Border: #E5E7EB

**Typography:**
- Headings: 24-28px, bold
- Body: 16px, regular
- Small text: 14px

**Spacing:**
- Container padding: 20px
- Card margin: 12px
- Button padding: 16px vertical, 24px horizontal

**Components:**
- Cards: Rounded corners (12px), shadow, white background
- Buttons: Rounded (8px), bold text, 48px height
- Selections: Border highlight when active

---

## Mock Data

### Trial Recording Prompts
```javascript
// Choose one of these (use best judgment):
const prompts = {
  option1: "What did you enjoy most about last week and why?", // RECOMMENDED - relatable, recent, easier
  option2: "What led you to try AI Talk Coach and why?", // Reinforces motivation, may increase conversions
};

// Final choice: Use Option 1 by default
const DEFAULT_PROMPT = "What did you enjoy most about last week and why?";
```

### Mock Trial Results (If User Skips Recording)
```javascript
{
  clarity: 72,
  fillerWordsPerMinute: 8.5,
  wordsPerMinute: 145,
  transcript: "Well, um, my biggest achievement was when I, uh, led a team of 5 people to launch a new product. It was, like, really challenging but we, you know, pulled it off in just 3 months.",
}
```

---

## Development Phases

### Phase 1: Setup (30 min)
- Create Expo project in `/mobile` folder
- Install dependencies: React Navigation, expo-av
- Set up folder structure
- Create placeholder screens (9 files with basic text)
- Test navigation flow (all screens accessible)

### Phase 2: Build Screens (Screen by Screen)
- Screen 1: Welcome + animation
- Screen 2: Value prop cards
- Screen 3: Goals selection (multi-select)
- Screen 4: Motivation text
- Screen 5: Profile form
- Screen 6: Recording interface + backend integration
- Screen 7: Results display
- Screen 8: Cinematic animation
- Screen 9: Paywall + skip button

**After each screen:** Test on phone via Expo Go QR code

### Phase 3: Connect Data
- Set up OnboardingContext
- Pass data between screens
- Test full flow from start to finish

### Phase 4: Polish
- Add animations (welcome, cinematic)
- Fine-tune styling
- Add loading states
- Test edge cases (skip, back navigation)

---

## Backend API Requirements

**Existing Endpoints (from web app):**
- `POST /api/v1/trial_sessions` - Create trial session
- `POST /api/v1/trial_sessions/:token/upload` - Upload audio
- `GET /api/v1/trial_sessions/:token/status` - Check processing
- `GET /api/v1/trial_sessions/:token` - Get results

**New Endpoints Needed (Later):**
- `POST /api/v1/users/onboarding` - Save onboarding data when user completes flow
- Body: { goals, communication_style, age_range, language, trial_session_token }

---

## Payment Integration (Later)

**Stripe Setup:**
- Add Stripe publishable key to `.env`
- Use `@stripe/stripe-react-native` for payment UI
- Create checkout session on backend
- Store payment method (don't charge yet)
- Backend tracks daily practice streak
- Charge only if user misses a day

**For Now:**
- Skip button bypasses payment
- Show Stripe UI placeholder (commented out)

---

## Testing Checklist

- [ ] All 9 screens render correctly
- [ ] Navigation flows from screen 1 → 9
- [ ] Multi-select goals works
- [ ] Profile form validates
- [ ] Recording starts/stops correctly
- [ ] Audio uploads to backend
- [ ] Results display (real or mock data)
- [ ] Cinematic animation plays
- [ ] Skip button works on paywall
- [ ] OnboardingContext stores all data
- [ ] App works on real iPhone (via QR code)

---

## Next Steps After Onboarding

**Main App Screens (Build Later):**
1. Home/Practice Screen - Record new sessions
2. Sessions List - View past recordings
3. Session Detail - Analysis + timeline
4. Progress - Charts and metrics
5. Settings - Profile, privacy, subscription

**Onboarding Completion:**
- Save onboarding data to backend
- Navigate to main app (HomeScreen)
- Show "Practice daily" reminder
- Track daily streak

---

## Notes

- Keep it simple and clean
- Focus on user flow, not perfection
- Test on real iPhone frequently
- Mock data is OK for now
- We'll add polish later

**Let's build this! 🚀**
