import * as Haptics from 'expo-haptics';
import { Platform } from 'react-native';

/**
 * Custom hook for consistent haptic feedback across the app
 * Provides semantic methods for different interaction types
 */
export const useHaptics = () => {
  // Check if haptics are supported (mainly for iOS, Android support varies)
  const isSupported = Platform.OS === 'ios' || Platform.OS === 'android';

  /**
   * Light impact - for subtle interactions
   * Use for: shuffle button, filter chips, category selection, onboarding transitions
   */
  const light = async () => {
    if (!isSupported) return;
    try {
      await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    } catch (error) {
      // Silently fail if haptics not available
      console.debug('Haptic feedback failed:', error);
    }
  };

  /**
   * Medium impact - for standard actions
   * Use for: recording start/stop, tab navigation, delete actions, drill start
   */
  const medium = async () => {
    if (!isSupported) return;
    try {
      await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    } catch (error) {
      console.debug('Haptic feedback failed:', error);
    }
  };

  /**
   * Heavy impact - for important/impactful actions
   * Currently unused per user preference, but available for future use
   */
  const heavy = async () => {
    if (!isSupported) return;
    try {
      await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Heavy);
    } catch (error) {
      console.debug('Haptic feedback failed:', error);
    }
  };

  /**
   * Success notification - for positive completions
   * Use for: session completion, trial recording complete
   */
  const success = async () => {
    if (!isSupported) return;
    try {
      await Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    } catch (error) {
      console.debug('Haptic feedback failed:', error);
    }
  };

  /**
   * Warning notification - for cautionary actions
   * Currently unused per user preference (regular feedback for delete), but available
   */
  const warning = async () => {
    if (!isSupported) return;
    try {
      await Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning);
    } catch (error) {
      console.debug('Haptic feedback failed:', error);
    }
  };

  /**
   * Error notification - for error states
   * Available for future use
   */
  const error = async () => {
    if (!isSupported) return;
    try {
      await Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
    } catch (error) {
      console.debug('Haptic feedback failed:', error);
    }
  };

  /**
   * Selection feedback - for toggles and selections
   * Use for: goal cards, pricing cards, pill buttons
   */
  const selection = async () => {
    if (!isSupported) return;
    try {
      await Haptics.selectionAsync();
    } catch (error) {
      console.debug('Haptic feedback failed:', error);
    }
  };

  return {
    light,
    medium,
    heavy,
    success,
    warning,
    error,
    selection,
  };
};
