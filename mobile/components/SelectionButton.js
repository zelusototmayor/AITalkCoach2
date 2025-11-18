import React from 'react';
import { TouchableOpacity, Text, StyleSheet, Image } from 'react-native';
import { COLORS, SPACING } from '../constants/colors';

export default function SelectionButton({ icon, title, isSelected, onPress, style }) {
  // Check if icon is an image (number from require) or emoji (string)
  const isImage = typeof icon === 'number';

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
      {icon && (
        isImage ? (
          <Image source={icon} style={styles.iconImage} resizeMode="contain" />
        ) : (
          <Text style={styles.icon}>{icon}</Text>
        )
      )}
      <Text style={[
        styles.title,
        isSelected && styles.selectedTitle,
      ]}>
        {title}
      </Text>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  button: {
    width: '48%',
    backgroundColor: COLORS.cardBackground,
    borderRadius: 12,
    borderWidth: 2,
    borderColor: COLORS.border,
    padding: SPACING.md,
    alignItems: 'center',
    justifyContent: 'center',
    minHeight: 80,
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
  selectedButton: {
    backgroundColor: COLORS.selectedBackground,
    borderColor: COLORS.selected,
    borderWidth: 2.5,
    shadowColor: COLORS.primary,
    shadowOpacity: 0.2,
    shadowRadius: 4,
    elevation: 4,
  },
  icon: {
    fontSize: 28,
    marginBottom: SPACING.xs,
  },
  iconImage: {
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
