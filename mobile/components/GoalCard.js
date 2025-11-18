import React from 'react';
import { TouchableOpacity, Text, StyleSheet, Image } from 'react-native';
import { COLORS, SPACING } from '../constants/colors';
import { useHaptics } from '../hooks/useHaptics';

export default function GoalCard({ goal, isSelected, onPress }) {
  const haptics = useHaptics();

  const handlePress = () => {
    haptics.selection();
    onPress();
  };

  return (
    <TouchableOpacity
      style={[
        styles.card,
        isSelected && styles.selectedCard,
      ]}
      onPress={handlePress}
      activeOpacity={0.7}
    >
      <Image source={goal.icon} style={styles.icon} resizeMode="contain" />
      <Text style={[
        styles.title,
        isSelected && styles.selectedTitle,
      ]}>
        {goal.title}
      </Text>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  card: {
    width: '100%',
    backgroundColor: COLORS.cardBackground,
    borderRadius: 16,
    padding: SPACING.md,
    alignItems: 'center',
    justifyContent: 'center',
    minHeight: 100,
    borderWidth: 2,
    borderColor: COLORS.border,
    marginBottom: SPACING.sm,
    shadowColor: COLORS.text,
    shadowOffset: {
      width: 0,
      height: 1,
    },
    shadowOpacity: 0.05,
    shadowRadius: 3,
    elevation: 2,
  },
  selectedCard: {
    backgroundColor: COLORS.selectedBackground,
    borderColor: COLORS.selected,
    borderWidth: 2.5,
    shadowColor: COLORS.primary,
    shadowOpacity: 0.2,
    shadowRadius: 4,
    elevation: 4,
  },
  icon: {
    width: 48,
    height: 48,
    marginBottom: SPACING.xs,
  },
  title: {
    fontSize: 14,
    fontWeight: '600',
    color: COLORS.text,
    textAlign: 'center',
  },
  selectedTitle: {
    color: COLORS.selected,
    fontWeight: 'bold',
  },
});
