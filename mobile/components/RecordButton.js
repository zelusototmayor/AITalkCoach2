import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import Svg, { Circle } from 'react-native-svg';
import { COLORS, SPACING } from '../constants/colors';

export default function RecordButton({
  isRecording,
  onPress,
  progress = 0, // 0 to 1
  disabled = false
}) {
  // Calculate the progress ring - larger than button so it's visible around it
  const svgSize = 220;
  const buttonSize = 200;
  const strokeWidth = 8;
  const radius = (svgSize - strokeWidth) / 2 - 5; // 5px padding from edge
  const circumference = 2 * Math.PI * radius;
  const strokeDashoffset = circumference - (progress * circumference);

  return (
    <View style={styles.container}>
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

      <TouchableOpacity
        style={[styles.button, disabled && styles.buttonDisabled]}
        onPress={onPress}
        disabled={disabled}
        activeOpacity={0.8}
      >
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
      </TouchableOpacity>
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
