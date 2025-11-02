import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import { COLORS, SPACING } from '../constants/colors';

/**
 * MetricScorecard Component
 * Displays a single metric with value, comparison, and info button
 *
 * @param {string} title - Metric title (e.g., "Overall Score")
 * @param {number} value - Current metric value
 * @param {string} displayValue - Formatted display value (e.g., "85%", "145 WPM")
 * @param {string} status - Status text (e.g., "Excellent", "Natural range")
 * @param {Object} comparison - Comparison to last session { delta: number, isImprovement: boolean }
 * @param {string} grade - Letter grade (optional, for overall score)
 * @param {function} onInfoPress - Callback when info icon is pressed
 * @param {string} iconEmoji - Emoji icon for the metric
 */
export default function MetricScorecard({
  title,
  value,
  displayValue,
  status,
  comparison,
  grade,
  onInfoPress,
  iconEmoji,
}) {
  // Determine comparison color
  const getComparisonColor = () => {
    if (!comparison) return COLORS.textSecondary;
    return comparison.isImprovement ? COLORS.success : COLORS.error;
  };

  // Determine comparison arrow
  const getComparisonArrow = () => {
    if (!comparison || comparison.delta === 0) return '—';
    return comparison.isImprovement ? '↑' : '↓';
  };

  // Format comparison text
  const getComparisonText = () => {
    if (!comparison) return 'No prev';
    if (comparison.delta === 0) return 'Same';

    const deltaText = Math.abs(comparison.delta).toFixed(1);
    return `${getComparisonArrow()} ${deltaText}%`;
  };

  return (
    <View style={styles.card}>
      {/* Header with title and info button */}
      <View style={styles.header}>
        <View style={styles.titleContainer}>
          <Text style={styles.title}>{title}</Text>
        </View>
        <TouchableOpacity onPress={onInfoPress} style={styles.infoButton}>
          <Text style={styles.infoIcon}>i</Text>
        </TouchableOpacity>
      </View>

      {/* Main Value */}
      <View style={styles.valueContainer}>
        <Text style={styles.value}>{displayValue}</Text>
        {grade && <Text style={styles.grade}>{grade}</Text>}
      </View>

      {/* Status */}
      {status && <Text style={styles.status}>{status}</Text>}

      {/* Comparison to Last Session */}
      <View style={styles.comparisonContainer}>
        <Text style={[styles.comparisonText, { color: getComparisonColor() }]}>
          {getComparisonText()}
        </Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: COLORS.cardBackground,
    borderRadius: 12,
    padding: 8,
    marginBottom: SPACING.sm,
    width: 82,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 4,
  },
  titleContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  iconEmoji: {
    fontSize: 20,
    marginRight: SPACING.xs,
  },
  title: {
    fontSize: 9,
    fontWeight: '600',
    color: COLORS.textSecondary,
    textTransform: 'uppercase',
    letterSpacing: 0.3,
  },
  infoButton: {
    width: 18,
    height: 18,
    borderRadius: 9,
    backgroundColor: COLORS.background,
    justifyContent: 'center',
    alignItems: 'center',
  },
  infoIcon: {
    fontSize: 11,
    fontWeight: '600',
    color: COLORS.primary,
  },
  valueContainer: {
    flexDirection: 'row',
    alignItems: 'baseline',
    marginBottom: 4,
  },
  value: {
    fontSize: 22,
    fontWeight: '700',
    color: COLORS.text,
  },
  grade: {
    fontSize: 16,
    fontWeight: '600',
    color: COLORS.primary,
    marginLeft: 4,
  },
  status: {
    fontSize: 10,
    color: COLORS.textSecondary,
    marginBottom: 4,
    lineHeight: 13,
  },
  comparisonContainer: {
    paddingTop: 4,
    borderTopWidth: 1,
    borderTopColor: COLORS.background,
  },
  comparisonText: {
    fontSize: 9,
    fontWeight: '600',
    lineHeight: 12,
  },
});
