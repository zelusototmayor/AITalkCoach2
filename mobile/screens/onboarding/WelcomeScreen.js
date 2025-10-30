import React, { useEffect } from 'react';
import { View, Text, StyleSheet } from 'react-native';
import WaveAnimation from '../../components/WaveAnimation';
import { COLORS, SPACING, TYPOGRAPHY } from '../../constants/colors';

export default function WelcomeScreen({ navigation }) {
  useEffect(() => {
    // Auto-advance to next screen after 2.5 seconds
    const timer = setTimeout(() => {
      navigation.navigate('ValueProp');
    }, 2500);

    // Cleanup timer if component unmounts
    return () => clearTimeout(timer);
  }, [navigation]);

  return (
    <View style={styles.container}>
      <View style={styles.content}>
        <View style={styles.animationContainer}>
          <WaveAnimation />
        </View>
        <Text style={styles.brandText}>AI Talk Coach</Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background,
    justifyContent: 'center',
    alignItems: 'center',
  },
  content: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  animationContainer: {
    marginBottom: SPACING.xxl,
  },
  brandText: {
    fontSize: 24,
    fontWeight: 'bold',
    color: COLORS.text,
    letterSpacing: 0.5,
    textAlign: 'center',
  },
});
