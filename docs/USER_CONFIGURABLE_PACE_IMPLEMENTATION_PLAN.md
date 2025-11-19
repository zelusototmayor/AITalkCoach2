# Implementation Plan: User-Configurable Target Speaking Pace

## Overview
Allow users to set a custom target WPM, which becomes their "optimal" pace. The system will derive acceptable ranges automatically. Users who don't customize will use current defaults (130-150 optimal, 110-170 acceptable).

### User Requirements
- **WPM Configuration**: Single target WPM (e.g., 140)
- **UI Location**: Settings page only
- **Defaults**: Keep current defaults (130-150 optimal, 110-170 acceptable) for users who don't customize
- **Range Logic**: User's target becomes optimal range (target ± 10), with acceptable range derived (target ± 30)

---

## Phase 1: Database & Model Layer (LOW COMPLEXITY)

### 1.1 Database Migration
**File**: New migration file
- Add `target_wpm` column to users table (integer, nullable, default: nil)
- When nil, system uses default values (130-150 optimal, 110-170 acceptable)

**Dependencies**: None
**Difficulty**: Easy
**Status**: ⬜ Not Started

### 1.2 User Model Updates
**File**: `/Users/zelu/ai_talk_coach/app/models/user.rb`
- Add validation for `target_wpm` (range: 60-240 WPM reasonable bounds)
- Add helper methods:
  - `optimal_wpm_range` - Returns user's target ± 10 WPM, or default 130-150
  - `acceptable_wpm_range` - Returns user's target ± 30 WPM, or default 110-170
  - `target_wpm_or_default` - Returns target_wpm or 140 (current midpoint)

**Dependencies**: 1.1 (migration)
**Difficulty**: Easy
**Status**: ⬜ Not Started

---

## Phase 2: Backend Analysis Services (MEDIUM-HIGH COMPLEXITY)

### 2.1 Analysis::Metrics Service
**File**: `/Users/zelu/ai_talk_coach/app/services/analysis/metrics.rb`
- Replace hardcoded constants with dynamic methods that accept user parameter
- Update methods:
  - `assess_speaking_rate(wpm, user)` - Use user's ranges
  - `score_speaking_pace(wpm, user)` - Use user's ranges for scoring
  - `calculate_speaking_metrics` - Accept user parameter, pass to sub-methods
- Keep constants as DEFAULT values for when user is nil

**Dependencies**: 1.2 (User model helpers)
**Difficulty**: Medium
**Risk**: ⚠️ High impact - central to all analysis
**Status**: ⬜ Not Started

### 2.2 Analysis::PriorityRecommender Service
**File**: `/Users/zelu/ai_talk_coach/app/services/analysis/priority_recommender.rb`
- Update pace analysis logic (lines 142-161) to use user's acceptable range
- Update target WPM calculation to use user's optimal range midpoint
- Update hardcoded strings mentioning "130-150 WPM" to dynamically reference user's range
- Update actionable steps (lines 449-466) to use user's ranges
- Update WPM scoring function (lines 409-414) to use user's ranges

**Dependencies**: 2.1 (Metrics service)
**Difficulty**: Medium
**Risk**: ⚠️ Affects coaching recommendations quality
**Status**: ⬜ Not Started

### 2.3 Analysis::RuleDetector Service
**File**: `/Users/zelu/ai_talk_coach/app/services/analysis/rule_detector.rb`
- Update `detect_slow_speaking_rate` (lines 138-159) to use user's acceptable minimum
- Update `detect_fast_speaking_rate` (lines 161-182) to use user's acceptable maximum
- Pass user object through detection pipeline

**Dependencies**: 2.1 (Metrics service)
**Difficulty**: Medium
**Status**: ⬜ Not Started

### 2.4 TrialSession Model
**File**: `/Users/zelu/ai_talk_coach/app/models/trial_session.rb`
- Update pace scoring logic (lines 122-130) to use user's optimal range
- Dynamic penalty calculation based on deviation from user's target

**Dependencies**: 1.2 (User model helpers)
**Difficulty**: Easy-Medium
**Status**: ⬜ Not Started

---

## Phase 3: Controllers & API (LOW-MEDIUM COMPLEXITY)

### 3.1 Settings Controller
**File**: `/Users/zelu/ai_talk_coach/app/controllers/settings_controller.rb`
- Add `target_wpm` to permitted parameters (line 20-22)
- Return validation errors if target_wpm out of bounds

**Dependencies**: 1.2 (User model)
**Difficulty**: Easy
**Status**: ⬜ Not Started

### 3.2 API Session Processing
**File**: `/Users/zelu/ai_talk_coach/app/jobs/sessions/process_job.rb`
- Ensure user object is passed to Analysis::Metrics.calculate_speaking_metrics

**Dependencies**: 2.1 (Metrics service updates)
**Difficulty**: Easy
**Risk**: ⚠️ Critical path - affects all new session analysis
**Status**: ⬜ Not Started

### 3.3 API Response Updates
**Files**:
- `/Users/zelu/ai_talk_coach/app/controllers/api/v1/coach_controller.rb`
- `/Users/zelu/ai_talk_coach/app/controllers/api/v1/progress_controller.rb`
- `/Users/zelu/ai_talk_coach/app/controllers/sessions_controller.rb`

**Changes**:
- Include user's target_wpm and ranges in API responses
- Ensure mobile app can access this data

**Dependencies**: 1.2 (User model)
**Difficulty**: Easy
**Status**: ⬜ Not Started

---

## Phase 4: Mobile App UI (MEDIUM COMPLEXITY)

### 4.1 Settings Screen
**File**: `/Users/zelu/ai_talk_coach/mobile/screens/profile/SettingsScreen.js`
- Add new section: "Speaking Pace Preferences"
- Add slider or number input for target WPM (range: 60-240)
- Show calculated optimal and acceptable ranges in real-time
- Display current setting (or "Using default: 140 WPM")
- Save via settings API endpoint

**Dependencies**: 3.1 (Settings controller)
**Difficulty**: Medium
**Status**: ⬜ Not Started

### 4.2 Metric Info Modal
**File**: `/Users/zelu/ai_talk_coach/mobile/components/MetricInfoModal.js`
- Update line 81: Change hardcoded "130-170 WPM" to user's optimal range
- Make idealRange dynamic based on user's settings

**Dependencies**: 3.3 (API includes user ranges)
**Difficulty**: Easy
**Status**: ⬜ Not Started

### 4.3 Session Report Screen
**File**: `/Users/zelu/ai_talk_coach/mobile/screens/practice/SessionReportScreen.js`
- Update `getPaceStatus` function (lines 196-199) to use user's optimal range
- Update status text to reference user's custom range
- Display "vs your target" instead of generic messaging

**Dependencies**: 3.3 (API includes user ranges)
**Difficulty**: Easy-Medium
**Status**: ⬜ Not Started

### 4.4 Coach Recommendation Card
**File**: `/Users/zelu/ai_talk_coach/mobile/components/CoachRecommendationCard.js`
- Ensure dynamic range display (already uses data from API)
- Verify formatting works with custom values

**Dependencies**: 2.2 (PriorityRecommender updates)
**Difficulty**: Easy
**Status**: ⬜ Not Started

---

## Phase 5: Testing & Validation (MEDIUM COMPLEXITY)

### 5.1 Backend Tests
**Tasks**:
- Test User model validations
- Test Analysis::Metrics with custom user ranges
- Test Analysis::PriorityRecommender recommendations accuracy
- Test edge cases: very slow targets (80 WPM), very fast targets (200 WPM)
- Test nil target_wpm falls back to defaults correctly

**Dependencies**: All Phase 1-3 changes
**Difficulty**: Medium
**Status**: ⬜ Not Started

### 5.2 Mobile Integration Tests
**Tasks**:
- Test settings UI save/load
- Test session report displays correct ranges
- Test coach recommendations reflect user's targets

**Dependencies**: All Phase 4 changes
**Difficulty**: Medium
**Status**: ⬜ Not Started

---

## Architecture Decisions & Considerations

### Design Pattern: Dependency Injection
- Pass user object through analysis pipeline rather than globals
- Maintains testability and flexibility

### Backwards Compatibility
- All existing sessions remain valid (analyzed with defaults)
- No data migration needed for analysis_data
- Future sessions automatically use user's preferences

### Range Derivation Logic
- **Optimal Range**: target_wpm ± 10 (e.g., 140 → 130-150)
- **Acceptable Range**: target_wpm ± 30 (e.g., 140 → 110-170)
- These deltas can be constants or configurable

### Validation Bounds
- Minimum: 60 WPM (slower than typical speech)
- Maximum: 240 WPM (faster than typical speech)
- Prevents unrealistic targets

### Fallback Strategy
- When `target_wpm` is nil → use current defaults
- When user object unavailable → use current defaults
- Graceful degradation ensures system stability

---

## Implementation Order & Dependencies

```
1. Database Migration (1.1)
   ↓
2. User Model Updates (1.2)
   ↓
3. Analysis Services (2.1, 2.2, 2.3, 2.4) - Can be parallel
   ↓
4. Controllers & API (3.1, 3.2, 3.3) - Sequential
   ↓
5. Mobile UI (4.1, 4.2, 4.3, 4.4) - Can be parallel
   ↓
6. Testing (5.1, 5.2)
```

---

## Risk Assessment

### HIGH RISK:
- **Analysis::Metrics changes** - Central to all scoring, must be bulletproof
- **Session processing job** - Critical path, affects all new sessions

### MEDIUM RISK:
- **PriorityRecommender** - Complex logic, many edge cases
- **Mobile settings UI** - User-facing, must be intuitive

### LOW RISK:
- **Database migration** - Straightforward column addition
- **Display components** - Mostly cosmetic updates

---

## Estimated Effort
- **Phase 1**: 1-2 hours
- **Phase 2**: 4-6 hours (most complex)
- **Phase 3**: 2-3 hours
- **Phase 4**: 3-4 hours
- **Phase 5**: 2-3 hours
- **Total**: 12-18 hours

---

## Success Criteria
1. ✅ Users can set target WPM in mobile settings
2. ✅ All coach recommendations respect user's target
3. ✅ Session analysis uses user's custom ranges
4. ✅ Users without custom settings see no change (default behavior)
5. ✅ No regressions in existing functionality
6. ✅ All tests pass

---

## Current Hardcoded Values Found

### Constants in `/Users/zelu/ai_talk_coach/app/services/analysis/metrics.rb:5-9`
```ruby
OPTIMAL_WPM_RANGE = (130..150).freeze
ACCEPTABLE_WPM_RANGE = (110..170).freeze
SLOW_WPM_THRESHOLD = 110
FAST_WPM_THRESHOLD = 170
```

### Additional Locations with Hardcoded Values
- `/Users/zelu/ai_talk_coach/app/services/analysis/priority_recommender.rb:142` - "130-150 WPM"
- `/Users/zelu/ai_talk_coach/app/services/analysis/priority_recommender.rb:144-146` - Checks `wpm < 110 || wpm > 170`
- `/Users/zelu/ai_talk_coach/app/services/analysis/priority_recommender.rb:409-414` - WPM scoring tiers
- `/Users/zelu/ai_talk_coach/app/models/trial_session.rb:122-130` - Pace scoring (130-170 range)
- `/Users/zelu/ai_talk_coach/mobile/components/MetricInfoModal.js:81` - "130-170 WPM (Natural)"
- `/Users/zelu/ai_talk_coach/mobile/screens/practice/SessionReportScreen.js:196-199` - Status function (130-170 range)

---

## Progress Tracking

**Last Updated**: 2025-11-18
**Overall Status**: ⬜ Planning Complete - Ready for Implementation
**Completed Phases**: 0/5
**Estimated Completion**: TBD

---

## Notes
- This plan assumes the mobile app is React Native/Expo
- All file paths are absolute from project root
- Line numbers are approximate and may shift during implementation
- Consider adding feature flag for gradual rollout
