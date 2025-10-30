# AI Talk Coach - Mobile App

## Onboarding Flow Implementation - Screens 1-3

This mobile app implements the first 3 screens of the onboarding flow:

### Implemented Screens

1. **Welcome Screen** - Animated sound wave introduction with auto-advance
2. **Value Proposition Screen** - Shows 4 key benefits in a 2x2 grid
3. **Speaking Goals Screen** - Multi-select interface for choosing speaking goals

### Project Structure

```
mobile/
├── App.js                          # Main app entry with navigation
├── navigation/
│   └── OnboardingNavigator.js      # Stack navigator for onboarding
├── screens/onboarding/
│   ├── WelcomeScreen.js            # Screen 1: Welcome with animation
│   ├── ValuePropScreen.js          # Screen 2: Value propositions
│   └── GoalsScreen.js              # Screen 3: Speaking goals selection
├── components/
│   ├── Button.js                   # Reusable button component
│   ├── GoalCard.js                 # Selectable goal card
│   └── WaveAnimation.js            # Animated sound waves
├── constants/
│   ├── colors.js                   # Color palette & styling constants
│   └── onboardingData.js           # Static content (goals, benefits)
└── package.json
```

### How to Run

#### Prerequisites
- Install Expo Go app on your iPhone/Android device
- Or have an iOS Simulator/Android Emulator installed

#### Start Development Server

```bash
cd mobile
npm start
```

This will start the Expo development server and display a QR code.

#### Run on Device
1. Open the Expo Go app on your phone
2. Scan the QR code displayed in your terminal
3. The app will load and start at the Welcome screen

#### Run on Simulator/Emulator

For iOS:
```bash
npm run ios
```

For Android:
```bash
npm run android
```

### Features

#### Screen 1: Welcome
- Animated sound wave bars (4 bars moving up/down)
- Auto-advances after 2.5 seconds
- Centered branding

#### Screen 2: Value Proposition
- Header: "Master the #1 skill that opens every door"
- 4 benefit cards:
  - Build deeper relationships
  - Advance your career faster
  - Feel confident in any room
  - Inspire and influence others
- Manual navigation with Continue button

#### Screen 3: Speaking Goals
- Header: "What are your speaking goals?"
- 8 selectable goal cards:
  - Public Speaking
  - Acing Interviews
  - Sales & Pitching
  - Podcasting/Content
  - Social Skills
  - Acting/Performance
  - Leadership
  - Other
- Multi-select functionality (tap to select/deselect)
- Continue button (disabled until at least 1 goal selected)
- Pagination dots showing screen 3 of 9

### Design System

**Colors:**
- Primary: #4F46E5 (Indigo)
- Secondary: #10B981 (Green)
- Background: #FFFFFF
- Card Background: #F9FAFB
- Text: #111827
- Selected: #EEF2FF

**Typography:**
- Headings: 28px, bold
- Body: 16px, regular
- Small: 14px

### Next Steps

Screens 4-9 to be implemented:
- Screen 4: Motivation
- Screen 5: User Profile
- Screen 6: Trial Recording
- Screen 7: Results + Upsell
- Screen 8: Cinematic Transition
- Screen 9: Paywall

### Dependencies

- React Native (Expo)
- React Navigation (@react-navigation/native, @react-navigation/stack)
- expo-av (for future audio recording)
- react-native-screens
- react-native-safe-area-context

### Notes

- No backend integration yet (screens 1-3 are frontend only)
- Selected goals are logged to console for now
- Context/state management to be added when implementing remaining screens
