import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import { COLORS, SPACING } from '../constants/colors';
import Button from './Button';

/**
 * CoachRecommendationCard Component
 * Mobile-optimized coach recommendation display
 *
 * @param {Object} recommendation - Recommendation object from API
 * @param {Object} weeklyFocus - Current weekly focus (if any)
 * @param {boolean} isFirstSession - Whether this is user's first session
 * @param {function} onViewPlan - Callback to view full coaching plan
 * @param {function} onPractice - Callback to practice the recommended area
 */
export default function CoachRecommendationCard({
  recommendation,
  weeklyFocus,
  isFirstSession,
  onViewPlan,
  onPractice,
}) {
  // Handle first session case
  if (isFirstSession) {
    return (
      <View style={[styles.card, styles.cardFirst]}>
        <View style={styles.badge}>
          <Text style={styles.badgeText}>WELCOME 👋</Text>
        </View>

        <Text style={styles.title}>Great First Session!</Text>
        <Text style={styles.description}>
          Record a few more sessions to get personalized coaching recommendations and track your
          progress over time.
        </Text>

        <TouchableOpacity style={styles.singleButton} onPress={onPractice}>
          <Text style={styles.singleButtonText}>Record Another Session</Text>
        </TouchableOpacity>
      </View>
    );
  }

  // No recommendation available
  if (!recommendation || !recommendation.focus_this_week || recommendation.focus_this_week.length === 0) {
    return (
      <View style={styles.card}>
        <Text style={styles.title}>Keep Practicing!</Text>
        <Text style={styles.description}>
          Complete more sessions to get personalized coaching recommendations.
        </Text>
      </View>
    );
  }

  const topRecommendation = recommendation.focus_this_week[0];

  // Check if recommendation matches weekly focus
  const matchesWeeklyFocus = weeklyFocus && weeklyFocus.focus_type === topRecommendation.type;

  // Get badge and color based on state
  const getBadgeInfo = () => {
    if (matchesWeeklyFocus) {
      return { text: 'KEEP GOING 💪', color: COLORS.success };
    } else if (weeklyFocus) {
      return { text: 'NEW INSIGHT 💡', color: COLORS.primary };
    } else {
      return { text: 'RECOMMENDED 🎯', color: COLORS.primary };
    }
  };

  const badgeInfo = getBadgeInfo();

  // Get improvement area display name
  const getAreaDisplayName = (type) => {
    const names = {
      reduce_fillers: 'Reduce Filler Words',
      improve_pace: 'Improve Speaking Pace',
      enhance_clarity: 'Enhance Clarity',
      boost_engagement: 'Boost Engagement',
      increase_fluency: 'Increase Fluency',
      fix_long_pauses: 'Fix Long Pauses',
      professional_language: 'Use Professional Language',
    };
    return names[type] || type;
  };

  // Format metric value for display
  const formatValue = (value, type) => {
    if (type === 'reduce_fillers') {
      return `${(value * 100).toFixed(1)}%`;
    } else if (type === 'improve_pace') {
      return `${Math.round(value)} WPM`;
    } else {
      return `${(value * 100).toFixed(0)}%`;
    }
  };

  return (
    <View style={[styles.card, { borderLeftColor: badgeInfo.color }]}>
      <View style={[styles.badge, { backgroundColor: badgeInfo.color + '20' }]}>
        <Text style={[styles.badgeText, { color: badgeInfo.color }]}>
          {badgeInfo.text}
        </Text>
      </View>

      <Text style={styles.title}>
        {getAreaDisplayName(topRecommendation.type)}
      </Text>

      {/* Current vs Target */}
      <View style={styles.metricsRow}>
        <View style={styles.metricBox}>
          <Text style={styles.metricLabel}>Current</Text>
          <Text style={styles.metricValue}>
            {formatValue(topRecommendation.current_value, topRecommendation.type)}
          </Text>
        </View>
        <View style={styles.metricArrow}>
          <Text style={styles.arrowText}>→</Text>
        </View>
        <View style={styles.metricBox}>
          <Text style={styles.metricLabel}>Target</Text>
          <Text style={[styles.metricValue, styles.metricValueTarget]}>
            {formatValue(topRecommendation.target_value, topRecommendation.type)}
          </Text>
        </View>
      </View>

      {/* Action steps (condensed to top 2) */}
      {topRecommendation.actionable_steps && topRecommendation.actionable_steps.length > 0 && (
        <View style={styles.stepsContainer}>
          <Text style={styles.stepsTitle}>How to improve:</Text>
          {topRecommendation.actionable_steps.slice(0, 2).map((step, index) => (
            <View key={index} style={styles.stepItem}>
              <Text style={styles.stepBullet}>•</Text>
              <Text style={styles.stepText}>{step}</Text>
            </View>
          ))}
        </View>
      )}

      {/* Action Buttons */}
      <View style={styles.buttonsContainer}>
        <TouchableOpacity
          style={[styles.button, styles.buttonSecondary]}
          onPress={onViewPlan}
        >
          <Text style={styles.buttonSecondaryText}>View Full Plan</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.button, styles.buttonPrimary]}
          onPress={onPractice}
        >
          <Text style={styles.buttonPrimaryText}>Practice This</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: COLORS.cardBackground,
    borderRadius: 16,
    padding: SPACING.md,
    marginBottom: SPACING.md,
    borderLeftWidth: 4,
    borderLeftColor: COLORS.primary,
  },
  cardFirst: {
    borderLeftColor: COLORS.success,
  },
  badge: {
    alignSelf: 'flex-start',
    paddingHorizontal: SPACING.sm,
    paddingVertical: 4,
    borderRadius: 12,
    marginBottom: SPACING.sm,
  },
  badgeText: {
    fontSize: 11,
    fontWeight: '700',
    letterSpacing: 0.5,
  },
  title: {
    fontSize: 20,
    fontWeight: '700',
    color: COLORS.text,
    marginBottom: SPACING.sm,
  },
  description: {
    fontSize: 15,
    color: COLORS.textSecondary,
    lineHeight: 22,
    marginBottom: SPACING.md,
  },
  metricsRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: SPACING.md,
    paddingVertical: SPACING.sm,
    backgroundColor: COLORS.background,
    borderRadius: 12,
  },
  metricBox: {
    flex: 1,
    alignItems: 'center',
  },
  metricArrow: {
    paddingHorizontal: SPACING.sm,
  },
  arrowText: {
    fontSize: 20,
    color: COLORS.primary,
  },
  metricLabel: {
    fontSize: 12,
    color: COLORS.textSecondary,
    marginBottom: 4,
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
  metricValue: {
    fontSize: 24,
    fontWeight: '700',
    color: COLORS.text,
  },
  metricValueTarget: {
    color: COLORS.primary,
  },
  stepsContainer: {
    marginBottom: SPACING.md,
  },
  stepsTitle: {
    fontSize: 14,
    fontWeight: '600',
    color: COLORS.text,
    marginBottom: SPACING.xs,
  },
  stepItem: {
    flexDirection: 'row',
    marginTop: SPACING.xs,
  },
  stepBullet: {
    fontSize: 16,
    color: COLORS.primary,
    marginRight: SPACING.xs,
    marginTop: 2,
  },
  stepText: {
    flex: 1,
    fontSize: 14,
    color: COLORS.textSecondary,
    lineHeight: 20,
  },
  buttonsContainer: {
    flexDirection: 'row',
    gap: SPACING.sm,
  },
  button: {
    flex: 1,
    paddingVertical: SPACING.sm,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
  buttonPrimary: {
    backgroundColor: COLORS.primary,
  },
  buttonSecondary: {
    backgroundColor: 'transparent',
    borderWidth: 2,
    borderColor: COLORS.primary,
  },
  buttonPrimaryText: {
    fontSize: 15,
    fontWeight: '600',
    color: COLORS.white,
  },
  buttonSecondaryText: {
    fontSize: 15,
    fontWeight: '600',
    color: COLORS.primary,
  },
  singleButton: {
    backgroundColor: COLORS.primary,
    paddingVertical: SPACING.md,
    borderRadius: 12,
    alignItems: 'center',
  },
  singleButtonText: {
    fontSize: 16,
    fontWeight: '600',
    color: COLORS.white,
  },
});
