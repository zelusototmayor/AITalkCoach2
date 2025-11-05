/**
 * Feature Flags Configuration
 *
 * Controls visibility of features across the mobile app.
 * Used for staged rollouts and A/B testing.
 */

// FREE FOREVER FEATURE
// Controls display of "free forever" messaging in onboarding
// Set to false for initial App Store submission
// Set to true after approval to enable trial extension messaging
export const SHOW_FREE_FOREVER = false;

// Export all feature flags
export default {
  SHOW_FREE_FOREVER,
};
