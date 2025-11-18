import React from 'react';
import { TouchableOpacity, Text, StyleSheet } from 'react-native';
import { COLORS, SPACING } from '../constants/colors';
import { useHaptics } from '../hooks/useHaptics';

export default function PillButton({ label, isSelected, onPress, style }) {
  const haptics = useHaptics();

  const handlePress = () => {
    haptics.selection();
    onPress();
  };

  return (
    <TouchableOpacity
      style={[
        styles.button,
        isSelected && styles.selectedButton,
        style,
      ]}
      onPress={handlePress}
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
