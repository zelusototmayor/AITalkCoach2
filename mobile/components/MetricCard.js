import React from 'react';
import { View, Text, StyleSheet, Image } from 'react-native';
import { COLORS, SPACING } from '../constants/colors';

export default function MetricCard({ icon, label, value, subtitle, style }) {
  // Support both emoji strings and image sources
  const isImageSource = typeof icon === 'number' || (typeof icon === 'object' && icon !== null);

  return (
    <View style={[styles.card, style]}>
      {icon && (
        isImageSource ? (
          <Image source={icon} style={styles.iconImage} resizeMode="contain" />
        ) : (
          <Text style={styles.icon}>{icon}</Text>
        )
      )}
      <Text style={styles.value}>{value}</Text>
      <Text style={styles.label}>{label}</Text>
      {subtitle && <Text style={styles.subtitle}>{subtitle}</Text>}
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: COLORS.cardBackground,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: COLORS.border,
    padding: SPACING.sm,
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: COLORS.text,
    shadowOffset: {
      width: 0,
      height: 1,
    },
    shadowOpacity: 0.05,
    shadowRadius: 3,
    elevation: 2,
    flex: 1,
    minHeight: 80,
  },
  icon: {
    fontSize: 24,
    marginBottom: SPACING.xs,
  },
  iconImage: {
    width: 24,
    height: 24,
    marginBottom: SPACING.xs,
  },
  value: {
    fontSize: 20,
    fontWeight: 'bold',
    color: COLORS.primary,
    marginBottom: 4,
  },
  label: {
    fontSize: 12,
    fontWeight: '600',
    color: COLORS.text,
    textAlign: 'center',
  },
  subtitle: {
    fontSize: 10,
    fontWeight: '500',
    color: COLORS.textSecondary,
    textAlign: 'center',
    marginTop: 2,
  },
});
