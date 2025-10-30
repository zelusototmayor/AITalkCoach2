import React from 'react';
import { createStackNavigator } from '@react-navigation/stack';
import WelcomeScreen from '../screens/onboarding/WelcomeScreen';
import ValuePropScreen from '../screens/onboarding/ValuePropScreen';
import GoalsScreen from '../screens/onboarding/GoalsScreen';
import MotivationScreen from '../screens/onboarding/MotivationScreen';
import ProfileScreen from '../screens/onboarding/ProfileScreen';
import TrialRecordingScreen from '../screens/onboarding/TrialRecordingScreen';

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
      <Stack.Screen name="ValueProp" component={ValuePropScreen} />
      <Stack.Screen name="Goals" component={GoalsScreen} />
      <Stack.Screen name="Motivation" component={MotivationScreen} />
      <Stack.Screen name="Profile" component={ProfileScreen} />
      <Stack.Screen name="TrialRecording" component={TrialRecordingScreen} />
    </Stack.Navigator>
  );
}
