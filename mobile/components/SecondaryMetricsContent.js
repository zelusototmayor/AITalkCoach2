import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { COLORS, SPACING } from '../constants/colors';

/**
 * SecondaryMetricsContent Component
 * Displays secondary metrics like pace consistency, longest pause, fluency
 *
 * @param {Object} metrics - Metrics object from session analysis_json
 */
export default function SecondaryMetricsContent({ metrics = {} }) {
  // Define secondary metrics to display
  const secondaryMetrics = [
    {
      label: 'Pace Consistency',
      value: metrics.pace_consistency,
      format: 'percentage',
      description: 'How consistent your speaking pace was',
    },
    {
      label: 'Longest Pause',
      value: metrics.longest_pause_ms,
      format: 'seconds',
      description: 'The longest gap in your speech',
    },
    {
      label: 'Fluency Score',
      value: metrics.fluency_score,
      format: 'percentage',
      description: 'How smooth and natural your speech flows',
    },
    {
      label: 'Engagement Score',
      value: metrics.engagement_score,
      format: 'percentage',
      description: 'How engaging and dynamic your delivery is',
    },
  ];

  // Format value based on type
  const formatValue = (value, format) => {
    if (value === null || value === undefined) return 'N/A';

    switch (format) {
      case 'percentage':
        return `${(value * 100).toFixed(0)}%`;
      case 'seconds':
        return `${(value / 1000).toFixed(1)}s`;
      case 'duration':
        const totalSeconds = Math.floor(value / 1000);
        const minutes = Math.floor(totalSeconds / 60);
        const seconds = totalSeconds % 60;
        return `${minutes}:${seconds.toString().padStart(2, '0')}`;
      default:
        return value.toString();
    }
  };

  return (
    <View style={styles.container}>
      {secondaryMetrics.map((metric, index) => (
        <View key={index} style={styles.metricCard}>
          <View style={styles.metricInfo}>
            <Text style={styles.metricLabel}>{metric.label}</Text>
            <Text style={styles.metricDescription}>{metric.description}</Text>
          </View>
          <Text style={styles.metricValue}>
            {formatValue(metric.value, metric.format)}
          </Text>
        </View>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    gap: SPACING.sm,
  },
  metricCard: {
    backgroundColor: COLORS.background,
    borderRadius: 12,
    padding: SPACING.md,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  metricInfo: {
    flex: 1,
  },
  metricLabel: {
    fontSize: 15,
    fontWeight: '600',
    color: COLORS.text,
    marginBottom: 2,
  },
  metricDescription: {
    fontSize: 12,
    color: COLORS.textSecondary,
    lineHeight: 16,
  },
  metricValue: {
    fontSize: 24,
    fontWeight: '700',
    color: COLORS.primary,
    marginLeft: SPACING.sm,
  },
});
