import React from 'react';
import { TouchableOpacity, Text, StyleSheet } from 'react-native';
import { COLORS, SPACING } from '../constants/colors';

export default function PillButton({ label, isSelected, onPress, style }) {
  return (
    <TouchableOpacity
      style={[
        styles.button,
        isSelected && styles.selectedButton,
        style,
      ]}
      onPress={onPress}
      activeOpacity={0.7}
    >
      <Text style={[
        styles.label,
        isSelected && styles.selectedLabel,
      ]}>
        {label}
      </Text>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  button: {
    backgroundColor: COLORS.cardBackground,
    borderRadius: 20,
    borderWidth: 2,
    borderColor: COLORS.border,
    paddingVertical: 6,
    paddingHorizontal: 10,
    marginRight: SPACING.sm,
    marginBottom: SPACING.sm,
  },
  selectedButton: {
    backgroundColor: COLORS.selectedBackground,
    borderColor: COLORS.primary,
    borderWidth: 2.5,
  },
  label: {
    fontSize: 12,
    fontWeight: '600',
    color: COLORS.text,
    textAlign: 'center',
  },
  selectedLabel: {
    color: COLORS.primary,
    fontWeight: 'bold',
  },
});
