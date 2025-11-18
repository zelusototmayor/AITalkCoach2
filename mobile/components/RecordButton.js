import React, { useEffect } from 'react';
import { View, Text, StyleSheet, TouchableWithoutFeedback } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import Svg, { Circle } from 'react-native-svg';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withRepeat,
  withTiming,
  withSequence,
  Easing,
  cancelAnimation
} from 'react-native-reanimated';
import { COLORS, SPACING } from '../constants/colors';
import { useHaptics } from '../hooks/useHaptics';
import { animationValues } from '../utils/animationConfigs';

export default function RecordButton({
  isRecording,
  onPress,
  progress = 0, // 0 to 1
  disabled = false
}) {
  const haptics = useHaptics();

  // Pulse animations
  const pulseScale = useSharedValue(1);
  const pulseOpacity = useSharedValue(0.3);

  useEffect(() => {
    if (!isRecording && !disabled) {
      // Start pulsing animation when idle
      pulseScale.value = withRepeat(
        withSequence(
          withTiming(animationValues.pulseScaleMax, {
            duration: animationValues.pulseDuration / 2,
            easing: Easing.inOut(Easing.ease),
          }),
          withTiming(animationValues.pulseScaleMin, {
            duration: animationValues.pulseDuration / 2,
            easing: Easing.inOut(Easing.ease),
          })
        ),
        -1, // infinite
        false
      );

      pulseOpacity.value = withRepeat(
        withSequence(
          withTiming(animationValues.pulseOpacityMax, {
            duration: animationValues.pulseDuration / 2,
            easing: Easing.inOut(Easing.ease),
          }),
          withTiming(animationValues.pulseOpacityMin, {
            duration: animationValues.pulseDuration / 2,
            easing: Easing.inOut(Easing.ease),
          })
        ),
        -1, // infinite
        false
      );
    } else {
      // Stop pulsing when recording
      cancelAnimation(pulseScale);
      cancelAnimation(pulseOpacity);
      pulseScale.value = withTiming(1, { duration: 200 });
      pulseOpacity.value = withTiming(0, { duration: 200 });
    }
  }, [isRecording, disabled]);

  const handlePress = () => {
    haptics.medium();
    onPress();
  };

  // Animated styles
  const buttonAnimatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: pulseScale.value }],
  }));

  const pulseRingStyle = useAnimatedStyle(() => ({
    opacity: pulseOpacity.value,
  }));

  // Calculate the progress ring - larger than button so it's visible around it
  const svgSize = 220;
  const buttonSize = 200;
  const strokeWidth = 8;
  const radius = (svgSize - strokeWidth) / 2 - 5; // 5px padding from edge
  const circumference = 2 * Math.PI * radius;
  const strokeDashoffset = circumference - (progress * circumference);

  return (
    <View style={styles.container}>
      {/* Pulse ring - shown when idle (not recording) */}
      {!isRecording && !disabled && (
        <Animated.View style={[styles.pulseRing, pulseRingStyle]} />
      )}

      {/* Progress ring overlay - shown around button when recording */}
      {isRecording && (
        <Svg
          width={svgSize}
          height={svgSize}
          style={styles.progressSvg}
        >
          {/* Background circle */}
          <Circle
            cx={svgSize / 2}
            cy={svgSize / 2}
            r={radius}
            stroke={COLORS.border}
            strokeWidth={strokeWidth}
            fill="none"
          />
          {/* Progress circle */}
          <Circle
            cx={svgSize / 2}
            cy={svgSize / 2}
            r={radius}
            stroke="#FF6B35"
            strokeWidth={strokeWidth}
            fill="none"
            strokeDasharray={circumference}
            strokeDashoffset={strokeDashoffset}
            strokeLinecap="round"
            rotation="-90"
            origin={`${svgSize / 2}, ${svgSize / 2}`}
          />
        </Svg>
      )}

      <TouchableWithoutFeedback onPress={handlePress} disabled={disabled}>
        <Animated.View style={[styles.button, disabled && styles.buttonDisabled, buttonAnimatedStyle]}>
          {/* Microphone icon */}
          <View style={[styles.iconContainer, isRecording && styles.iconContainerRecording]}>
            <Ionicons
              name={isRecording ? "mic" : "mic-outline"}
              size={64}
              color={isRecording ? COLORS.primary : COLORS.text}
            />
          </View>

          {/* Text */}
          {!isRecording && (
            <Text style={styles.text}>Tap to Start</Text>
          )}
        </Animated.View>
      </TouchableWithoutFeedback>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    justifyContent: 'center',
    position: 'relative',
    width: 220,
    height: 220,
  },
  pulseRing: {
    position: 'absolute',
    width: 220,
    height: 220,
    borderRadius: 110,
    borderWidth: 3,
    borderColor: COLORS.primary,
    backgroundColor: 'transparent',
  },
  progressSvg: {
    position: 'absolute',
    top: 0,
    left: 0,
  },
  button: {
    width: 200,
    height: 200,
    borderRadius: 100,
    backgroundColor: COLORS.cardBackground,
    borderWidth: 4,
    borderColor: COLORS.border,
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: COLORS.primary,
    shadowOffset: {
      width: 0,
      height: 4,
    },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 8,
  },
  buttonDisabled: {
    opacity: 0.5,
  },
  iconContainer: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  iconContainerRecording: {
    transform: [{ scale: 1.1 }],
  },
  text: {
    fontSize: 16,
    fontWeight: '600',
    color: COLORS.text,
    marginTop: SPACING.sm,
  },
});
