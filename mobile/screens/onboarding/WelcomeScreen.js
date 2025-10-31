import React, { useEffect } from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import WaveAnimation from '../../components/WaveAnimation';
import AnimatedBackground from '../../components/AnimatedBackground';
import { COLORS, SPACING, TYPOGRAPHY } from '../../constants/colors';

export default function WelcomeScreen({ navigation }) {
  useEffect(() => {
    // Check if user is already logged in
    // TODO: Implement proper auth check when auth is integrated
    // const checkAuth = async () => {
    //   const isLoggedIn = await checkUserAuth();
    //   if (isLoggedIn) {
    //     navigation.navigate('Main'); // or whatever the main page is called
    //   }
    // };
    // checkAuth();
  }, [navigation]);

  return (
    <View style={styles.container}>
      <AnimatedBackground />
      <View style={styles.content}>
        <Text style={styles.welcomeText}>welcome</Text>
        <View style={styles.animationContainer}>
          <WaveAnimation />
        </View>
        <Text style={styles.brandText}>AI Talk Coach</Text>
      </View>

      <View style={styles.buttonContainer}>
        <TouchableOpacity
          style={styles.primaryButton}
          onPress={() => navigation.navigate('SignUp')}
        >
          <Text style={styles.primaryButtonText}>Get Started</Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={styles.secondaryButton}
          onPress={() => navigation.navigate('Login')}
        >
          <Text style={styles.secondaryButtonText}>Login</Text>
        </TouchableOpacity>

        {/* Development skip button */}
        <TouchableOpacity
          style={styles.skipButton}
          onPress={() => navigation.navigate('ValueProp')}
        >
          <Text style={styles.skipButtonText}>Skip (Dev)</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background,
    justifyContent: 'space-between',
    paddingTop: 100,
    paddingBottom: 40,
  },
  content: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  welcomeText: {
    fontSize: 18,
    fontWeight: '400',
    color: COLORS.text,
    marginBottom: SPACING.md,
    opacity: 0.7,
  },
  animationContainer: {
    marginBottom: SPACING.xl,
  },
  brandText: {
    fontSize: 24,
    fontWeight: 'bold',
    color: COLORS.text,
    letterSpacing: 0.5,
    textAlign: 'center',
  },
  buttonContainer: {
    paddingHorizontal: SPACING.lg,
    gap: SPACING.md,
  },
  primaryButton: {
    backgroundColor: COLORS.primary,
    paddingVertical: 16,
    paddingHorizontal: 32,
    borderRadius: 12,
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  primaryButtonText: {
    color: COLORS.background,
    fontSize: 16,
    fontWeight: '600',
    letterSpacing: 0.5,
  },
  secondaryButton: {
    backgroundColor: COLORS.background,
    paddingVertical: 16,
    paddingHorizontal: 32,
    borderRadius: 12,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: COLORS.border,
  },
  secondaryButtonText: {
    color: COLORS.text,
    fontSize: 16,
    fontWeight: '600',
    letterSpacing: 0.5,
  },
  skipButton: {
    paddingVertical: 12,
    paddingHorizontal: 24,
    alignItems: 'center',
    marginTop: 8,
  },
  skipButtonText: {
    color: COLORS.textSecondary,
    fontSize: 13,
    fontWeight: '500',
    opacity: 0.6,
  },
});
