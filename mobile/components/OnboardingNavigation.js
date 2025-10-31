import React from 'react';
import { View, StyleSheet, Animated } from 'react-native';
import Button from './Button';
import { COLORS, SPACING } from '../constants/colors';

export default function OnboardingNavigation({
  currentStep,
  totalSteps,
  onContinue,
  continueDisabled = false,
  continueText = 'Continue →',
}) {
  return (
    <View style={styles.navigationContainer}>
      {/* Continue Button */}
      <Button
        title={continueText}
        onPress={onContinue}
        variant="primary"
        disabled={continueDisabled}
        style={styles.continueButton}
      />

      {/* Pagination Dots */}
      <View style={styles.dotsContainer}>
        {[...Array(totalSteps)].map((_, index) => (
          <Animated.View
            key={index}
            style={[
              styles.dot,
              index === currentStep && styles.activeDot,
            ]}
          />
        ))}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  navigationContainer: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    paddingHorizontal: SPACING.lg,
    paddingBottom: SPACING.xl,
    paddingTop: SPACING.md,
    pointerEvents: 'box-none',
  },
  continueButton: {
    width: '100%',
    marginBottom: SPACING.lg,
  },
  dotsContainer: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    gap: SPACING.xs,
    paddingVertical: SPACING.sm,
  },
  dot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: COLORS.border,
    transition: 'all 0.3s ease',
  },
  activeDot: {
    backgroundColor: COLORS.primary,
    width: 24,
    height: 8,
    borderRadius: 4,
  },
});
