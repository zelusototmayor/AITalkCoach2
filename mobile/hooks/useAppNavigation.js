import { useNavigation } from '@react-navigation/native';

/**
 * Centralized navigation hook for app-wide navigation
 * Provides a consistent way to navigate between screens from any component
 */
export const useAppNavigation = () => {
  const navigation = useNavigation();

  // Centralized mapping of screen IDs to route names
  const screenMap = {
    practice: 'Practice',
    progress: 'Progress',
    coach: 'Coach',
    prompts: 'Prompts',
    profile: 'ProfileMain',
  };

  /**
   * Navigate to a screen by its ID
   * @param {string} screenId - The screen identifier (practice, progress, coach, prompts, profile)
   */
  const navigateToScreen = (screenId) => {
    const routeName = screenMap[screenId];
    if (routeName) {
      navigation.navigate(routeName);
    } else {
      console.warn(`Unknown screen ID: ${screenId}`);
    }
  };

  /**
   * Get the current active screen name
   * @returns {string|null} The current route name
   */
  const getCurrentScreen = () => {
    const currentRoute = navigation.getState()?.routes[navigation.getState()?.index];
    return currentRoute?.name || null;
  };

  return {
    navigateToScreen,
    getCurrentScreen,
    navigation,
  };
};
