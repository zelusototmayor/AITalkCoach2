import React, { useEffect, useRef } from 'react';
import { StatusBar } from 'expo-status-bar';
import { NavigationContainer } from '@react-navigation/native';
import { View, ActivityIndicator, StyleSheet } from 'react-native';
import MainNavigator from './navigation/MainNavigator';
import { OnboardingProvider } from './context/OnboardingContext';
import { AuthProvider, useAuth } from './context/AuthContext';
import { COLORS } from './constants/colors';
import analytics from './services/analytics';

// Separate component to access auth context
function AppContent() {
  const { isLoading } = useAuth();
  const navigationRef = useRef();
  const routeNameRef = useRef();

  if (isLoading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color={COLORS.primary} />
      </View>
    );
  }

  return (
    <NavigationContainer
      ref={navigationRef}
      onReady={() => {
        // Save initial route name
        routeNameRef.current = navigationRef.current?.getCurrentRoute()?.name;
      }}
      onStateChange={async () => {
        const previousRouteName = routeNameRef.current;
        const currentRoute = navigationRef.current?.getCurrentRoute();
        const currentRouteName = currentRoute?.name;

        if (previousRouteName !== currentRouteName) {
          // Track screen view with analytics
          analytics.trackScreen(currentRouteName, {
            previous_screen: previousRouteName,
            ...currentRoute?.params,
          });
        }

        // Save the current route name for next comparison
        routeNameRef.current = currentRouteName;
      }}
    >
      <StatusBar style="auto" />
      <MainNavigator />
    </NavigationContainer>
  );
}

export default function App() {
  useEffect(() => {
    // Initialize analytics on app launch
    const initAnalytics = async () => {
      // TODO: Set MIXPANEL_TOKEN in environment variables or constants
      // For now, using the same token as web (replace with mobile-specific token if desired)
      const MIXPANEL_TOKEN = process.env.MIXPANEL_TOKEN || '44bf717b1ffcda5744f92721374b15da';

      await analytics.init(MIXPANEL_TOKEN);

      // Track app launch
      analytics.track('App Launched', {
        launch_time: new Date().toISOString(),
      });
    };

    initAnalytics();
  }, []);

  return (
    <AuthProvider>
      <OnboardingProvider>
        <AppContent />
      </OnboardingProvider>
    </AuthProvider>
  );
}

const styles = StyleSheet.create({
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: COLORS.background,
  },
});
