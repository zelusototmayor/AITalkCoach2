import React, { useEffect, useRef } from 'react';
import { View, Animated, StyleSheet } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { COLORS } from '../constants/colors';

export default function WaveAnimation() {
  // Create animated values for 5 bars (different sizes like logo)
  const bar1 = useRef(new Animated.Value(0)).current; // Short
  const bar2 = useRef(new Animated.Value(0)).current; // Medium-tall
  const bar3 = useRef(new Animated.Value(0)).current; // Tallest (center)
  const bar4 = useRef(new Animated.Value(0)).current; // Medium-tall
  const bar5 = useRef(new Animated.Value(0)).current; // Short

  useEffect(() => {
    // Create staggered animations for each bar
    const createWaveAnimation = (animatedValue, delay, baseHeight, maxHeight) => {
      return Animated.loop(
        Animated.sequence([
          Animated.timing(animatedValue, {
            toValue: 1,
            duration: 700,
            delay,
            useNativeDriver: false, // Height animation requires false
          }),
          Animated.timing(animatedValue, {
            toValue: 0,
            duration: 700,
            useNativeDriver: false, // Height animation requires false
          }),
        ])
      );
    };

    // Start all animations with different delays for wave effect
    Animated.parallel([
      createWaveAnimation(bar1, 0),
      createWaveAnimation(bar2, 140),
      createWaveAnimation(bar3, 280),
      createWaveAnimation(bar4, 420),
      createWaveAnimation(bar5, 560),
    ]).start();
  }, [bar1, bar2, bar3, bar4, bar5]);

  const getBarStyle = (animatedValue, baseHeight, maxHeight) => ({
    height: animatedValue.interpolate({
      inputRange: [0, 1],
      outputRange: [baseHeight, maxHeight],
    }),
    opacity: animatedValue.interpolate({
      inputRange: [0, 1],
      outputRange: [0.5, 1],
    }),
  });

  return (
    <View style={styles.logoContainer}>
      <LinearGradient
        colors={[COLORS.gradientStart, COLORS.gradientEnd]}
        start={{ x: 0, y: 0 }}
        end={{ x: 1, y: 1 }}
        style={styles.gradientBackground}
      >
        <View style={styles.barsContainer}>
          <Animated.View style={[styles.bar, getBarStyle(bar1, 50, 70)]} />
          <Animated.View style={[styles.bar, getBarStyle(bar2, 65, 90)]} />
          <Animated.View style={[styles.bar, getBarStyle(bar3, 80, 110)]} />
          <Animated.View style={[styles.bar, getBarStyle(bar4, 65, 90)]} />
          <Animated.View style={[styles.bar, getBarStyle(bar5, 50, 70)]} />
        </View>
      </LinearGradient>
    </View>
  );
}

const styles = StyleSheet.create({
  logoContainer: {
    width: 120,
    height: 120,
    borderRadius: 28,
    overflow: 'hidden',
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 4,
    },
    shadowOpacity: 0.15,
    shadowRadius: 8,
    elevation: 8,
  },
  gradientBackground: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  barsContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 10,
    height: 120,
  },
  bar: {
    width: 10,
    backgroundColor: '#FFFFFF',
    borderRadius: 5,
  },
});
