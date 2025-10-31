import React, { useEffect, useRef } from 'react';
import { View, StyleSheet, Animated, Dimensions } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { COLORS } from '../constants/colors';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');

// Convert hex color to rgba
const hexToRgba = (hex, alpha) => {
  const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
  return result
    ? `rgba(${parseInt(result[1], 16)}, ${parseInt(result[2], 16)}, ${parseInt(result[3], 16)}, ${alpha})`
    : `rgba(255, 138, 76, ${alpha})`; // Fallback orange
};

// Animated gradient layer component
const AnimatedGradientLayer = ({ delay, duration }) => {
  const translateX = useRef(new Animated.Value(-SCREEN_WIDTH * 0.5)).current;
  const translateY = useRef(new Animated.Value(-SCREEN_HEIGHT * 0.5)).current;

  useEffect(() => {
    // Delay start for staggered wave effect
    setTimeout(() => {
      const animateWave = () => {
        // Reset to start position
        translateX.setValue(-SCREEN_WIDTH * 0.5);
        translateY.setValue(-SCREEN_HEIGHT * 0.5);

        // Animate diagonally from top-left to bottom-right
        Animated.parallel([
          Animated.timing(translateX, {
            toValue: SCREEN_WIDTH * 0.5,
            duration: duration,
            useNativeDriver: true,
          }),
          Animated.timing(translateY, {
            toValue: SCREEN_HEIGHT * 0.5,
            duration: duration,
            useNativeDriver: true,
          }),
        ]).start(() => {
          // Loop the animation
          animateWave();
        });
      };

      animateWave();
    }, delay);
  }, [duration, delay]);

  // Create a very subtle orange gradient with smooth falloff
  const orangeColor = COLORS.primary || '#FF8A4C';

  return (
    <Animated.View
      style={[
        styles.gradientLayer,
        {
          transform: [
            { translateX },
            { translateY },
          ],
        },
      ]}
    >
      <LinearGradient
        colors={[
          'transparent',
          hexToRgba(orangeColor, 0.03),
          hexToRgba(orangeColor, 0.08),
          hexToRgba(orangeColor, 0.12),
          hexToRgba(orangeColor, 0.08),
          hexToRgba(orangeColor, 0.03),
          'transparent',
        ]}
        start={{ x: 0, y: 0 }}
        end={{ x: 1, y: 1 }}
        style={styles.gradient}
      />
    </Animated.View>
  );
};

export default function AnimatedBackground() {
  // Create multiple gradient layers with different timings for complex wave effect
  const layers = [
    { delay: 0, duration: 12000 },
    { delay: 4000, duration: 15000 },
    { delay: 8000, duration: 13000 },
  ];

  return (
    <View style={styles.container} pointerEvents="none">
      {layers.map((layer, index) => (
        <AnimatedGradientLayer
          key={index}
          delay={layer.delay}
          duration={layer.duration}
        />
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    overflow: 'hidden',
    zIndex: 0,
  },
  gradientLayer: {
    position: 'absolute',
    width: SCREEN_WIDTH * 2,
    height: SCREEN_HEIGHT * 2,
    top: -SCREEN_HEIGHT * 0.5,
    left: -SCREEN_WIDTH * 0.5,
  },
  gradient: {
    flex: 1,
    width: '100%',
    height: '100%',
  },
});
