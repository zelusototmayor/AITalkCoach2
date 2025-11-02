import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { COLORS, SPACING } from '../constants/colors';

export default function PromptListCard({
  category,
  title,
  description,
  promptText,
  duration,
  focusAreas,
  onPractice,
  style
}) {
  const formatDuration = (seconds) => {
    if (seconds < 60) return `${seconds}s`;
    return `${Math.floor(seconds / 60)}m`;
  };

  const getCategoryColor = (cat) => {
    const colors = {
      'Presentation': COLORS.primary,
      'Conversation': '#3B82F6',
      'Storytelling': '#8B5CF6',
      'Practice Drills': '#10B981',
    };
    return colors[cat] || COLORS.textSecondary;
  };

  return (
    <View style={[styles.card, style]}>
      {/* Category Tag */}
      <View style={[styles.categoryTag, { backgroundColor: getCategoryColor(category) + '20' }]}>
        <Text style={[styles.categoryText, { color: getCategoryColor(category) }]}>
          {category}
        </Text>
      </View>

      {/* Title */}
      <Text style={styles.title}>{title}</Text>

      {/* Description */}
      {description && (
        <Text style={styles.description}>{description}</Text>
      )}

      {/* Prompt Text (collapsible/expandable) */}
      {promptText && (
        <View style={styles.promptContainer}>
          <Text style={styles.promptText} numberOfLines={2}>
            "{promptText}"
          </Text>
        </View>
      )}

      {/* Metadata Row */}
      <View style={styles.metadataRow}>
        {duration && (
          <View style={styles.metadataItem}>
            <Ionicons name="time-outline" size={14} color={COLORS.textSecondary} />
            <Text style={styles.metadataText}>{formatDuration(duration)}</Text>
          </View>
        )}
        {focusAreas && focusAreas.length > 0 && (
          <View style={styles.metadataItem}>
            <Ionicons name="flag-outline" size={14} color={COLORS.textSecondary} />
            <Text style={styles.metadataText} numberOfLines={1}>
              {focusAreas.slice(0, 2).join(', ')}
            </Text>
          </View>
        )}
      </View>

      {/* Practice Button */}
      <TouchableOpacity
        style={styles.practiceButton}
        onPress={onPractice}
        activeOpacity={0.8}
      >
        <Text style={styles.practiceButtonText}>Practice</Text>
        <Ionicons name="arrow-forward" size={16} color="#FFFFFF" />
      </TouchableOpacity>
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
  categoryTag: {
    alignSelf: 'flex-start',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 6,
    marginBottom: SPACING.xs,
  },
  categoryText: {
    fontSize: 10,
    fontWeight: '700',
    textTransform: 'uppercase',
  },
  title: {
    fontSize: 16,
    fontWeight: '600',
    color: COLORS.text,
    marginBottom: SPACING.xs,
  },
  description: {
    fontSize: 13,
    color: COLORS.textSecondary,
    lineHeight: 18,
    marginBottom: SPACING.xs,
  },
  promptContainer: {
    backgroundColor: COLORS.background,
    padding: SPACING.sm,
    borderRadius: 8,
    marginBottom: SPACING.sm,
  },
  promptText: {
    fontSize: 13,
    color: COLORS.text,
    fontStyle: 'italic',
    lineHeight: 18,
  },
  metadataRow: {
    flexDirection: 'row',
    gap: SPACING.md,
    marginBottom: SPACING.sm,
    flexWrap: 'wrap',
  },
  metadataItem: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  metadataText: {
    fontSize: 12,
    color: COLORS.textSecondary,
  },
  practiceButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
    backgroundColor: COLORS.primary,
    paddingVertical: 10,
    borderRadius: 8,
  },
  practiceButtonText: {
    fontSize: 14,
    fontWeight: '600',
    color: '#FFFFFF',
  },
});
