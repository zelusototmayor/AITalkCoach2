import React from 'react';
import { createStackNavigator } from '@react-navigation/stack';
import { COLORS } from '../constants/colors';
import { useAuth } from '../context/AuthContext';

// Import navigators
import OnboardingNavigator from './OnboardingNavigator';

// Import screens
import WelcomeScreen from '../screens/onboarding/WelcomeScreen';
import SignUpScreen from '../screens/auth/SignUpScreen';
import LoginScreen from '../screens/auth/LoginScreen';
import PracticeScreen from '../screens/practice/PracticeScreen';
import SessionProcessingScreen from '../screens/practice/SessionProcessingScreen';
import SessionReportScreen from '../screens/practice/SessionReportScreen';
import ProgressScreen from '../screens/progress/ProgressScreen';
import CoachScreen from '../screens/coach/CoachScreen';
import HistoryScreen from '../screens/history/HistoryScreen';
import PromptsScreen from '../screens/prompts/PromptsScreen';
import ProfileScreen from '../screens/profile/ProfileScreen';
import SettingsScreen from '../screens/profile/SettingsScreen';
import PrivacyScreen from '../screens/profile/PrivacyScreen';

const Stack = createStackNavigator();
const AuthStack = createStackNavigator();

// Auth Stack for login/signup
function AuthNavigator() {
  return (
    <AuthStack.Navigator
      screenOptions={{
        headerShown: false,
        cardStyle: { backgroundColor: '#FFFFFF' },
      }}
    >
      <AuthStack.Screen name="Welcome" component={WelcomeScreen} />
      <AuthStack.Screen name="Login" component={LoginScreen} />
      <AuthStack.Screen name="SignUp" component={SignUpScreen} />
    </AuthStack.Navigator>
  );
}

// Main Stack Navigator - uses custom BottomNavigation component for tabs
function AppStack() {
  return (
    <Stack.Navigator
      initialRouteName="Practice"
      screenOptions={{
        headerShown: false,
        cardStyle: { backgroundColor: '#FFFFFF' },
        animation: 'none',
        gestureEnabled: true,
      }}
    >
      <Stack.Screen name="Practice" component={PracticeScreen} />
      <Stack.Screen name="Progress" component={ProgressScreen} />
      <Stack.Screen name="Coach" component={CoachScreen} />
      <Stack.Screen name="Prompts" component={PromptsScreen} />
      <Stack.Screen name="ProfileMain" component={ProfileScreen} />
      <Stack.Screen name="History" component={HistoryScreen} />
      <Stack.Screen name="SessionProcessing" component={SessionProcessingScreen} />
      <Stack.Screen name="SessionReport" component={SessionReportScreen} />
      <Stack.Screen name="Settings" component={SettingsScreen} />
      <Stack.Screen name="Privacy" component={PrivacyScreen} />
    </Stack.Navigator>
  );
}

// Main Navigator that checks auth and onboarding status
export default function MainNavigator() {
  const { isAuthenticated, user } = useAuth();

  // Not authenticated - show auth flow (Welcome/Login/SignUp)
  if (!isAuthenticated) {
    return <AuthNavigator />;
  }

  // Authenticated but needs onboarding - show onboarding flow
  if (user && !user.onboarding_completed) {
    return <OnboardingNavigator />;
  }

  // Authenticated and onboarding complete - show main app
  return <AppStack />;
}