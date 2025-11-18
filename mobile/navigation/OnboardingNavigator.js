import React from 'react';
import { createStackNavigator } from '@react-navigation/stack';
import ValuePropScreen from '../screens/onboarding/ValuePropScreen';
import GoalsScreen from '../screens/onboarding/GoalsScreen';
import MotivationScreen from '../screens/onboarding/MotivationScreen';
import ProfileScreen from '../screens/onboarding/ProfileScreen';
import TrialRecordingScreen from '../screens/onboarding/TrialRecordingScreen';
import TrialProcessingScreen from '../screens/onboarding/TrialProcessingScreen';
import ResultsScreen from '../screens/onboarding/ResultsScreen';
import CinematicScreen from '../screens/onboarding/CinematicScreen';
import PaywallScreen from '../screens/onboarding/PaywallScreen';
import { OnboardingMusicProvider } from '../context/OnboardingMusicContext';

const Stack = createStackNavigator();

export default function OnboardingNavigator() {
  return (
    <OnboardingMusicProvider>
      <Stack.Navigator
        initialRouteName="ValueProp"
        screenOptions={{
          headerShown: false,
          cardStyle: { backgroundColor: '#FFFFFF' },
        }}
      >
        <Stack.Screen name="ValueProp" component={ValuePropScreen} />
        <Stack.Screen name="Goals" component={GoalsScreen} />
        <Stack.Screen name="Motivation" component={MotivationScreen} />
        <Stack.Screen name="Profile" component={ProfileScreen} />
        <Stack.Screen name="TrialRecording" component={TrialRecordingScreen} />
        <Stack.Screen name="TrialProcessing" component={TrialProcessingScreen} />
        <Stack.Screen name="Results" component={ResultsScreen} />
        <Stack.Screen name="Cinematic" component={CinematicScreen} />
        <Stack.Screen name="Paywall" component={PaywallScreen} />
      </Stack.Navigator>
    </OnboardingMusicProvider>
  );
}
