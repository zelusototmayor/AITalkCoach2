import React, { useState } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ScrollView } from 'react-native';
import { COLORS, SPACING } from '../constants/colors';

/**
 * IssuesListContent Component
 * Displays session issues with filtering by category
 *
 * @param {Array} issues - Array of issue objects from API
 * @param {function} onTimestampPress - Callback when timestamp is pressed (seeks audio)
 */
export default function IssuesListContent({ issues = [], onTimestampPress }) {
  const [selectedCategory, setSelectedCategory] = useState('all');

  // Get issue counts by category
  const categoryCounts = issues.reduce((acc, issue) => {
    const category = issue.category || 'other';
    acc[category] = (acc[category] || 0) + 1;
    return acc;
  }, {});

  // Define category filters
  const categories = [
    { id: 'all', label: 'All', count: issues.length },
    { id: 'filler_words', label: 'Fillers', count: categoryCounts.filler_words || 0 },
    { id: 'pace_issues', label: 'Pace', count: categoryCounts.pace_issues || 0 },
    { id: 'clarity_issues', label: 'Clarity', count: categoryCounts.clarity_issues || 0 },
  ];

  // Filter issues by selected category
  const filteredIssues =
    selectedCategory === 'all'
      ? issues
      : issues.filter((issue) => issue.category === selectedCategory);

  // Format timestamp for display (ms to MM:SS)
  const formatTimestamp = (ms) => {
    const seconds = Math.floor(ms / 1000);
    const minutes = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  };

  // Get category badge color
  const getCategoryColor = (category) => {
    const colors = {
      filler_words: '#FF6B6B',
      pace_issues: '#4ECDC4',
      clarity_issues: '#FFB347',
      long_pause: '#95A5A6',
      unprofessional_language: '#9B59B6',
    };
    return colors[category] || COLORS.textSecondary;
  };

  if (issues.length === 0) {
    return (
      <View style={styles.emptyContainer}>
        <Text style={styles.emptyIcon}>✨</Text>
        <Text style={styles.emptyText}>No issues found!</Text>
        <Text style={styles.emptySubtext}>Great job on this session.</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      {/* Category Filters */}
      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        style={styles.filtersContainer}
        contentContainerStyle={styles.filtersContent}
      >
        {categories.map((category) => (
          <TouchableOpacity
            key={category.id}
            style={[
              styles.filterPill,
              selectedCategory === category.id && styles.filterPillActive,
            ]}
            onPress={() => setSelectedCategory(category.id)}
          >
            <Text
              style={[
                styles.filterPillText,
                selectedCategory === category.id && styles.filterPillTextActive,
              ]}
            >
              {category.label} {category.count > 0 && `(${category.count})`}
            </Text>
          </TouchableOpacity>
        ))}
      </ScrollView>

      {/* Issues List */}
      <View style={styles.issuesList}>
        {filteredIssues.map((issue, index) => (
          <View key={index} style={styles.issueCard}>
            {/* Timestamp Button */}
            <TouchableOpacity
              style={styles.timestampButton}
              onPress={() => onTimestampPress && onTimestampPress(issue.start_ms)}
            >
              <Text style={styles.timestampText}>
                {formatTimestamp(issue.start_ms)}
              </Text>
            </TouchableOpacity>

            {/* Category Badge */}
            <View
              style={[
                styles.categoryBadge,
                { backgroundColor: getCategoryColor(issue.category) + '20' },
              ]}
            >
              <Text
                style={[
                  styles.categoryBadgeText,
                  { color: getCategoryColor(issue.category) },
                ]}
              >
                {issue.category?.replace('_', ' ').toUpperCase() || 'OTHER'}
              </Text>
            </View>

            {/* Issue Text Quote */}
            {issue.text && (
              <Text style={styles.issueText}>"{issue.text}"</Text>
            )}

            {/* Coaching Tip */}
            {issue.tip && (
              <View style={styles.tipContainer}>
                <Text style={styles.tipLabel}>💡 Tip:</Text>
                <Text style={styles.tipText}>{issue.tip}</Text>
              </View>
            )}
          </View>
        ))}
      </View>

      {filteredIssues.length === 0 && (
        <View style={styles.emptyContainer}>
          <Text style={styles.emptyText}>No {selectedCategory} issues</Text>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  filtersContainer: {
    marginBottom: SPACING.md,
  },
  filtersContent: {
    paddingRight: SPACING.md,
  },
  filterPill: {
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.xs,
    borderRadius: 20,
    backgroundColor: COLORS.background,
    marginRight: SPACING.xs,
  },
  filterPillActive: {
    backgroundColor: COLORS.primary,
  },
  filterPillText: {
    fontSize: 14,
    fontWeight: '600',
    color: COLORS.textSecondary,
  },
  filterPillTextActive: {
    color: COLORS.white,
  },
  issuesList: {
    gap: SPACING.sm,
  },
  issueCard: {
    backgroundColor: COLORS.background,
    borderRadius: 12,
    padding: SPACING.sm,
    marginBottom: SPACING.xs,
  },
  timestampButton: {
    alignSelf: 'flex-start',
    backgroundColor: COLORS.primary + '20',
    paddingHorizontal: SPACING.sm,
    paddingVertical: 4,
    borderRadius: 8,
    marginBottom: SPACING.xs,
  },
  timestampText: {
    fontSize: 12,
    fontWeight: '700',
    color: COLORS.primary,
  },
  categoryBadge: {
    alignSelf: 'flex-start',
    paddingHorizontal: SPACING.sm,
    paddingVertical: 2,
    borderRadius: 8,
    marginBottom: SPACING.xs,
  },
  categoryBadgeText: {
    fontSize: 10,
    fontWeight: '700',
    letterSpacing: 0.5,
  },
  issueText: {
    fontSize: 15,
    color: COLORS.text,
    fontStyle: 'italic',
    marginBottom: SPACING.xs,
    lineHeight: 22,
  },
  tipContainer: {
    flexDirection: 'row',
    paddingTop: SPACING.xs,
    borderTopWidth: 1,
    borderTopColor: COLORS.cardBackground,
  },
  tipLabel: {
    fontSize: 13,
    fontWeight: '600',
    color: COLORS.text,
    marginRight: SPACING.xs,
  },
  tipText: {
    flex: 1,
    fontSize: 13,
    color: COLORS.textSecondary,
    lineHeight: 18,
  },
  emptyContainer: {
    alignItems: 'center',
    paddingVertical: SPACING.xl,
  },
  emptyIcon: {
    fontSize: 48,
    marginBottom: SPACING.sm,
  },
  emptyText: {
    fontSize: 16,
    fontWeight: '600',
    color: COLORS.text,
    marginBottom: 4,
  },
  emptySubtext: {
    fontSize: 14,
    color: COLORS.textSecondary,
  },
});
