import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { COLORS, SPACING } from '../constants/colors';
import { useHaptics } from '../hooks/useHaptics';

export default function PromptCard({ prompt, onShuffle, canShuffle = true }) {
  const haptics = useHaptics();

  const handleShuffle = () => {
    haptics.light();
    onShuffle();
  };

  const getDifficultyColors = (diff) => {
    const colors = {
      'beginner': {
        background: '#d1fae5',
        text: '#065f46',
      },
      'intermediate': {
        background: '#fef3c7',
        text: '#92400e',
      },
      'advanced': {
        background: '#fee2e2',
        text: '#991b1b',
      },
    };
    return colors[diff?.toLowerCase()] || { background: '#e5e7eb', text: '#6b7280' };
  };

  // Handle null/undefined prompt
  if (!prompt) {
    return (
      <View style={styles.card}>
        <View style={styles.header}>
          <Text style={styles.label}>Loading prompt...</Text>
          {canShuffle && (
            <TouchableOpacity
              onPress={handleShuffle}
              style={styles.shuffleButton}
              activeOpacity={0.7}
            >
              <Ionicons name="shuffle" size={20} color={COLORS.primary} />
            </TouchableOpacity>
          )}
        </View>
        <Text style={styles.promptText}>Please wait while we load your prompt</Text>
      </View>
    );
  }

  return (
    <View style={styles.card}>
      <View style={styles.header}>
        <View style={styles.headerLeft}>
          <Text style={styles.label}>Recommended Prompt</Text>
          {prompt.difficulty && (
            <View style={[styles.difficultyBadge, { backgroundColor: getDifficultyColors(prompt.difficulty).background }]}>
              <Text style={[styles.difficultyText, { color: getDifficultyColors(prompt.difficulty).text }]}>
                {prompt.difficulty.toUpperCase()}
              </Text>
            </View>
          )}
        </View>
        {canShuffle && (
          <TouchableOpacity
            onPress={handleShuffle}
            style={styles.shuffleButton}
            activeOpacity={0.7}
          >
            <Ionicons name="shuffle" size={20} color={COLORS.primary} />
          </TouchableOpacity>
        )}
      </View>

      <Text style={styles.promptText}>{prompt.text || 'No prompt text available'}</Text>

      <View style={styles.footer}>
        <Text style={styles.category}>{prompt.category || 'General'}</Text>
        <View style={styles.timeBadge}>
          <Text style={styles.timeText}>{prompt.duration || 60}s</Text>
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
  headerLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  label: {
    fontSize: 11,
    fontWeight: '600',
    color: COLORS.textSecondary,
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
  difficultyBadge: {
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 6,
  },
  difficultyText: {
    fontSize: 9,
    fontWeight: '600',
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
