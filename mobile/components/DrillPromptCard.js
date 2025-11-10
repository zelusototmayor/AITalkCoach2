import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { COLORS, SPACING } from '../constants/colors';

export default function DrillPromptCard({
  drillTitle,
  drillDescription,
  drillReasoning,
  prompt,
  onShuffle,
  canShuffle = true
}) {
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
          <View style={styles.headerLeft}>
            <Ionicons name="fitness" size={18} color={COLORS.primary} />
            <Text style={styles.label}>DRILL EXERCISE</Text>
          </View>
          {canShuffle && (
            <TouchableOpacity
              onPress={onShuffle}
              style={styles.shuffleButton}
              activeOpacity={0.7}
            >
              <Ionicons name="shuffle" size={20} color={COLORS.primary} />
            </TouchableOpacity>
          )}
        </View>

        <Text style={styles.drillTitle}>{drillTitle}</Text>
        {drillDescription && (
          <Text style={styles.drillDescription}>{drillDescription}</Text>
        )}

        <View style={styles.divider} />

        <Text style={styles.promptLabel}>Loading prompt...</Text>
      </View>
    );
  }

  return (
    <View style={styles.card}>
      {/* Header with Drill Label */}
      <View style={styles.header}>
        <View style={styles.headerLeft}>
          <Ionicons name="fitness" size={18} color={COLORS.primary} />
          <Text style={styles.label}>DRILL EXERCISE</Text>
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
            onPress={onShuffle}
            style={styles.shuffleButton}
            activeOpacity={0.7}
          >
            <Ionicons name="shuffle" size={20} color={COLORS.primary} />
          </TouchableOpacity>
        )}
      </View>

      {/* Drill Title */}
      <Text style={styles.drillTitle}>{drillTitle}</Text>

      {/* Drill Instructions */}
      {drillDescription && (
        <View style={styles.instructionsContainer}>
          <Text style={styles.instructionsLabel}>Instructions:</Text>
          <Text style={styles.drillDescription}>{drillDescription}</Text>
        </View>
      )}

      {/* Drill Reasoning (Why this drill) */}
      {drillReasoning && (
        <View style={styles.reasoningContainer}>
          <Text style={styles.reasoningText}>{drillReasoning}</Text>
        </View>
      )}

      {/* Divider */}
      <View style={styles.divider} />

      {/* Speaking Prompt */}
      <View style={styles.promptSection}>
        <Text style={styles.promptLabel}>Speaking Prompt:</Text>
        <Text style={styles.promptText}>{prompt.text || 'No prompt text available'}</Text>
      </View>

      {/* Footer */}
      <View style={styles.footer}>
        <Text style={styles.category}>{prompt.category || 'Practice'}</Text>
        <View style={styles.timeBadge}>
          <Ionicons name="time-outline" size={14} color={COLORS.primary} style={{ marginRight: 4 }} />
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
    gap: 6,
  },
  label: {
    fontSize: 11,
    fontWeight: '600',
    color: COLORS.primary,
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
  drillTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: COLORS.text,
    marginBottom: SPACING.sm,
  },
  instructionsContainer: {
    backgroundColor: COLORS.selectedBackground,
    padding: SPACING.sm,
    borderRadius: 8,
    marginBottom: SPACING.sm,
  },
  instructionsLabel: {
    fontSize: 11,
    fontWeight: '600',
    color: COLORS.textSecondary,
    textTransform: 'uppercase',
    letterSpacing: 0.5,
    marginBottom: 4,
  },
  drillDescription: {
    fontSize: 14,
    fontWeight: '500',
    color: COLORS.text,
    lineHeight: 20,
  },
  reasoningContainer: {
    backgroundColor: COLORS.primary + '10',
    padding: SPACING.sm,
    borderRadius: 8,
    borderLeftWidth: 3,
    borderLeftColor: COLORS.primary,
    marginBottom: SPACING.sm,
  },
  reasoningText: {
    fontSize: 13,
    fontStyle: 'italic',
    color: COLORS.text,
    lineHeight: 18,
  },
  divider: {
    height: 1,
    backgroundColor: COLORS.border,
    marginVertical: SPACING.sm,
  },
  promptSection: {
    marginBottom: SPACING.sm,
  },
  promptLabel: {
    fontSize: 11,
    fontWeight: '600',
    color: COLORS.textSecondary,
    textTransform: 'uppercase',
    letterSpacing: 0.5,
    marginBottom: 6,
  },
  promptText: {
    fontSize: 15,
    fontWeight: '600',
    color: COLORS.text,
    lineHeight: 20,
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
    flexDirection: 'row',
    alignItems: 'center',
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
