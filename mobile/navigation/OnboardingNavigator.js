import React from 'react';
import { createStackNavigator } from '@react-navigation/stack';
import WelcomeScreen from '../screens/onboarding/WelcomeScreen';
import SignUpScreen from '../screens/auth/SignUpScreen';
import LoginScreen from '../screens/auth/LoginScreen';
import ValuePropScreen from '../screens/onboarding/ValuePropScreen';
import GoalsScreen from '../screens/onboarding/GoalsScreen';
import MotivationScreen from '../screens/onboarding/MotivationScreen';
import ProfileScreen from '../screens/onboarding/ProfileScreen';
import TrialRecordingScreen from '../screens/onboarding/TrialRecordingScreen';
import ResultsScreen from '../screens/onboarding/ResultsScreen';
import CinematicScreen from '../screens/onboarding/CinematicScreen';
import PaywallScreen from '../screens/onboarding/PaywallScreen';

const Stack = createStackNavigator();

export default function OnboardingNavigator() {
  return (
    <Stack.Navigator
      screenOptions={{
        headerShown: false,
        cardStyle: { backgroundColor: '#FFFFFF' },
      }}
    >
      <Stack.Screen name="Welcome" component={WelcomeScreen} />
      <Stack.Screen name="SignUp" component={SignUpScreen} />
      <Stack.Screen name="Login" component={LoginScreen} />
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
