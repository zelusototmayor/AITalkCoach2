import React from 'react';
import { StatusBar } from 'expo-status-bar';
import { NavigationContainer } from '@react-navigation/native';
import OnboardingNavigator from './navigation/OnboardingNavigator';
import { OnboardingProvider } from './context/OnboardingContext';

export default function App() {
  return (
    <OnboardingProvider>
      <NavigationContainer>
        <StatusBar style="auto" />
        <OnboardingNavigator />
      </NavigationContainer>
    </OnboardingProvider>
  );
}
