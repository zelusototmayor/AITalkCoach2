import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { COLORS, SPACING } from '../constants/colors';

export default function PromptCard({ prompt, onShuffle }) {
  return (
    <View style={styles.card}>
      <View style={styles.header}>
        <Text style={styles.label}>Recommended Prompt</Text>
        <TouchableOpacity
          onPress={onShuffle}
          style={styles.shuffleButton}
          activeOpacity={0.7}
        >
          <Ionicons name="shuffle" size={20} color={COLORS.primary} />
        </TouchableOpacity>
      </View>

      <Text style={styles.promptText}>{prompt.text}</Text>

      <View style={styles.footer}>
        <Text style={styles.category}>{prompt.category}</Text>
        <View style={styles.timeBadge}>
          <Text style={styles.timeText}>{prompt.duration}s</Text>
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: COLORS.cardBackground,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: COLORS.border,
    padding: SPACING.md,
    shadowColor: COLORS.text,
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.05,
    shadowRadius: 4,
    elevation: 3,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.xs,
  },
  label: {
    fontSize: 11,
    fontWeight: '600',
    color: COLORS.textSecondary,
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
  shuffleButton: {
    padding: SPACING.xs,
    backgroundColor: COLORS.selectedBackground,
    borderRadius: 8,
  },
  promptText: {
    fontSize: 15,
    fontWeight: '600',
    color: COLORS.text,
    lineHeight: 20,
    marginBottom: SPACING.sm,
  },
  footer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  category: {
    fontSize: 12,
    fontWeight: '500',
    color: COLORS.textSecondary,
  },
  timeBadge: {
    backgroundColor: COLORS.selectedBackground,
    paddingHorizontal: SPACING.sm,
    paddingVertical: 4,
    borderRadius: 8,
  },
  timeText: {
    fontSize: 12,
    fontWeight: 'bold',
    color: COLORS.primary,
  },
});
