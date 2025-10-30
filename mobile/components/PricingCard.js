import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import { COLORS, SPACING } from '../constants/colors';

export default function PricingCard({
  title,
  price,
  period,
  badge,
  savings,
  isSelected,
  onPress,
  style
}) {
  return (
    <TouchableOpacity
      style={[
        styles.card,
        isSelected && styles.selectedCard,
        style,
      ]}
      onPress={onPress}
      activeOpacity={0.7}
    >
      {badge && (
        <View style={styles.badge}>
          <Text style={styles.badgeText}>{badge}</Text>
        </View>
      )}

      <View style={styles.content}>
        <Text style={styles.title}>{title}</Text>
        <View style={styles.priceContainer}>
          <Text style={styles.price}>{price}</Text>
          <Text style={styles.period}>{period}</Text>
        </View>
        {savings && (
          <Text style={styles.savings}>{savings}</Text>
        )}
      </View>

      {isSelected && (
        <View style={styles.checkmark}>
          <Text style={styles.checkmarkText}>✓</Text>
        </View>
      )}
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: COLORS.cardBackground,
    borderRadius: 16,
    borderWidth: 2,
    borderColor: COLORS.border,
    padding: SPACING.lg,
    marginBottom: SPACING.md,
    shadowColor: COLORS.text,
    shadowOffset: {
      width: 0,
      height: 1,
    },
    shadowOpacity: 0.05,
    shadowRadius: 3,
    elevation: 2,
    position: 'relative',
  },
  selectedCard: {
    borderColor: COLORS.primary,
    backgroundColor: COLORS.selectedBackground,
    borderWidth: 2,
  },
  badge: {
    position: 'absolute',
    top: -10,
    right: 20,
    backgroundColor: COLORS.success,
    paddingHorizontal: SPACING.sm,
    paddingVertical: 4,
    borderRadius: 8,
    zIndex: 1,
  },
  badgeText: {
    fontSize: 12,
    fontWeight: 'bold',
    color: '#FFFFFF',
  },
  content: {
    alignItems: 'center',
  },
  title: {
    fontSize: 18,
    fontWeight: '600',
    color: COLORS.text,
    marginBottom: SPACING.sm,
  },
  priceContainer: {
    flexDirection: 'row',
    alignItems: 'baseline',
    marginBottom: SPACING.xs,
  },
  price: {
    fontSize: 32,
    fontWeight: 'bold',
    color: COLORS.primary,
  },
  period: {
    fontSize: 16,
    fontWeight: '500',
    color: COLORS.textSecondary,
    marginLeft: 4,
  },
  savings: {
    fontSize: 14,
    fontWeight: '500',
    color: COLORS.textSecondary,
  },
  checkmark: {
    position: 'absolute',
    top: SPACING.md,
    right: SPACING.md,
    width: 24,
    height: 24,
    borderRadius: 12,
    backgroundColor: COLORS.primary,
    alignItems: 'center',
    justifyContent: 'center',
  },
  checkmarkText: {
    fontSize: 14,
    fontWeight: 'bold',
    color: '#FFFFFF',
  },
});
