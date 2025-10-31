# Remaining Mobile Onboarding Tasks

## Status: Trial Recording Page - READY FOR APPROVAL
- ✅ Skip button moved to bottom right
- ✅ SVG microphone icon (replaces emoji)
- ✅ Pagination dots restored
- ✅ Progress ring animation fixed (orange circle fills around button)
- ✅ react-native-svg package installed

---

## Remaining Tasks

### 1. Results Page (Update with percentages & recommendations)
**Location:** `/mobile/screens/onboarding/ResultsScreen.js`

**Changes needed:**
- Show filler words as percentage (not just count like "8.5")
- Add recommendations based on thresholds for each metric:
  - **Filler words**: If >3%, show "Too high - pause when you don't know what to say"
  - **Pace**: If too fast/slow, show appropriate recommendation
  - **Other metrics**: Add similar contextual recommendations
- Use the same recommendation logic as the web app

**Reference:** Check web app for recommendation thresholds and messages

---

### 2. Cinematic Screen (Make whimsical & emphasize "free forever")
**Location:** `/mobile/screens/onboarding/CinematicScreen.js`

**Changes needed:**
- Make the screen more whimsical and engaging (currently feels bland)
- Make the entire experience richer and more motivational
- **CRITICAL**: Make the last phrase "It could be free forever" jump out and have massive impact
  - Should feel like it's leaping off the screen
  - Use larger font, bold, different color, or animation
  - Create emotional connection with this message

**Current messages:**
1. "We want you to improve as much as you do!"
2. "So we reward consistency"
3. "Practice every day, and the app is FREE FOREVER"

---

### 3. Paywall Screen (Side-by-side plans & benefits)
**Location:** `/mobile/screens/onboarding/PaywallScreen.js`

**Changes needed:**
- **Remove lightbulb emoji** from "How it Works" card to make it shorter
- **Show plans side-by-side** instead of stacked vertically
- **Add small benefits list** for each plan so it's clear what users get

**Current structure:** Plans are shown one on top of the other
**Desired structure:** Two plans displayed side-by-side with benefits visible

---

## Notes
- All screens should use the new OnboardingNavigation component with dots at bottom
- Maintain consistent spacing and styling with updated screens
- Test on actual device after each change

---

## Completed Tasks ✅
- Welcome Screen (welcome text, buttons, remove auto-forward)
- SignUp & Login screens created
- Navigation updated with auth screens
- Master the Skill page (subheading, richer cards with stats)
- Speaking Goals page ("Select all that apply" subheading)
- Global navigation changes (OnboardingNavigation component)
- You Are Not Alone page (richer, more compact cards)
- Trial Recording page (Skip button, SVG mic, progress animation)
