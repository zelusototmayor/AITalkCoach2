import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { COLORS, SPACING } from '../constants/colors';

export default function ProgressStatsRow({
  todayCompleted,
  todayTarget,
  weekCompleted,
  weekTarget,
  streakDays,
  style
}) {
  const StatBox = ({ label, value, subtitle }) => (
    <View style={styles.statBox}>
      <Text style={styles.statLabel}>{label}</Text>
      <Text style={styles.statValue}>{value}</Text>
      {subtitle && <Text style={styles.statSubtitle}>{subtitle}</Text>}
    </View>
  );

  return (
    <View style={[styles.container, style]}>
      <StatBox
        label="Today"
        value={`${todayCompleted}/${todayTarget}`}
        subtitle="sessions"
      />
      <StatBox
        label="Week"
        value={`${weekCompleted}/${weekTarget}`}
        subtitle="sessions"
      />
      <StatBox
        label="Streak"
        value={streakDays}
        subtitle={streakDays === 1 ? 'day' : 'days'}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    gap: SPACING.sm,
  },
  statBox: {
    flex: 1,
    backgroundColor: COLORS.background,
    borderRadius: 12,
    padding: SPACING.sm,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: COLORS.border,
  },
  statLabel: {
    fontSize: 11,
    fontWeight: '600',
    color: COLORS.textSecondary,
    marginBottom: 4,
    textTransform: 'uppercase',
  },
  statValue: {
    fontSize: 20,
    fontWeight: 'bold',
    color: COLORS.primary,
    marginBottom: 2,
  },
  statSubtitle: {
    fontSize: 10,
    color: COLORS.textSecondary,
  },
});
