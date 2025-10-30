import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { COLORS, SPACING } from '../constants/colors';

export default function RecordButton({
  isRecording,
  onPress,
  progress = 0, // 0 to 1
  disabled = false
}) {
  // Calculate the progress ring circumference
  const radius = 96; // Button radius minus border
  const strokeWidth = 6;
  const circumference = 2 * Math.PI * radius;
  const progressOffset = circumference - (progress * circumference);

  return (
    <View style={styles.container}>
      <TouchableOpacity
        style={[styles.button, disabled && styles.buttonDisabled]}
        onPress={onPress}
        disabled={disabled}
        activeOpacity={0.8}
      >
        {/* Microphone icon */}
        <View style={[styles.iconContainer, isRecording && styles.iconContainerRecording]}>
          <Text style={styles.icon}>🎤</Text>
        </View>

        {/* Text */}
        {!isRecording && (
          <Text style={styles.text}>Tap to Start</Text>
        )}
      </TouchableOpacity>

      {/* Progress ring overlay - only shown when recording */}
      {isRecording && progress > 0 && (
        <View style={styles.progressOverlay}>
          <View
            style={[
              styles.progressRing,
              {
                borderColor: COLORS.primary,
                borderWidth: strokeWidth,
                transform: [{ rotate: '-90deg' }],
              },
            ]}
          >
            <View
              style={[
                styles.progressRingFill,
                {
                  borderColor: COLORS.selectedBackground,
                  borderWidth: strokeWidth,
                  borderTopColor: 'transparent',
                  borderRightColor: progress < 0.25 ? 'transparent' : COLORS.primary,
                  borderBottomColor: progress < 0.5 ? 'transparent' : COLORS.primary,
                  borderLeftColor: progress < 0.75 ? 'transparent' : COLORS.primary,
                },
              ]}
            />
          </View>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    justifyContent: 'center',
    position: 'relative',
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
  progressOverlay: {
    position: 'absolute',
    width: 200,
    height: 200,
    alignItems: 'center',
    justifyContent: 'center',
    pointerEvents: 'none',
  },
  progressRing: {
    width: 200,
    height: 200,
    borderRadius: 100,
  },
  progressRingFill: {
    width: '100%',
    height: '100%',
    borderRadius: 100,
  },
  iconContainer: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  iconContainerRecording: {
    transform: [{ scale: 1.1 }],
  },
  icon: {
    fontSize: 60,
  },
  text: {
    fontSize: 16,
    fontWeight: '600',
    color: COLORS.text,
    marginTop: SPACING.sm,
  },
});
