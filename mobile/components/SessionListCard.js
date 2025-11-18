import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { COLORS, SPACING } from '../constants/colors';
import { useHaptics } from '../hooks/useHaptics';

export default function SessionListCard({
  session,
  onViewDetails,
  onDelete,
  style
}) {
  const haptics = useHaptics();

  const handleViewDetails = () => {
    haptics.medium();
    onViewDetails();
  };

  const handleDelete = () => {
    haptics.medium();
    onDelete();
  };
  const getStatusBadgeStyle = (status) => {
    switch (status) {
      case 'completed':
        return { backgroundColor: COLORS.success + '20', color: COLORS.success };
      case 'processing':
        return { backgroundColor: COLORS.warning + '20', color: COLORS.warning };
      case 'failed':
        return { backgroundColor: COLORS.danger + '20', color: COLORS.danger };
      default:
        return { backgroundColor: COLORS.textSecondary + '20', color: COLORS.textSecondary };
    }
  };

  const formatDate = (dateString) => {
    const date = new Date(dateString);
    const now = new Date();
    const diff = now - date;
    const hours = Math.floor(diff / (1000 * 60 * 60));
    const days = Math.floor(diff / (1000 * 60 * 60 * 24));

    if (hours < 1) return 'Just now';
    if (hours < 24) return `${hours}h ago`;
    if (days < 7) return `${days}d ago`;

    return date.toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: date.getFullYear() !== now.getFullYear() ? 'numeric' : undefined
    });
  };

  const statusStyle = getStatusBadgeStyle(session.processing_state || 'pending');

  return (
    <View style={[styles.card, style]}>
      {/* Header */}
      <View style={styles.header}>
        <View style={styles.headerLeft}>
          <Text style={styles.title} numberOfLines={1}>
            {session.title || 'Untitled Session'}
          </Text>
          <Text style={styles.dateText}>{formatDate(session.created_at)}</Text>
        </View>
        <View style={[styles.statusBadge, { backgroundColor: statusStyle.backgroundColor }]}>
          <Text style={[styles.statusText, { color: statusStyle.color }]}>
            {session.processing_state?.toUpperCase() || 'PENDING'}
          </Text>
        </View>
      </View>

      {/* Language Badge (if present) */}
      {session.language && (
        <View style={styles.languageBadge}>
          <Ionicons name="language-outline" size={14} color={COLORS.textSecondary} />
          <Text style={styles.languageText}>{session.language}</Text>
        </View>
      )}

      {/* Metrics (only if completed) */}
      {session.completed && session.analysis_data && (
        <View style={styles.metricsRow}>
          <View style={styles.metricItem}>
            <Ionicons name="flash" size={16} color={COLORS.primary} />
            <Text style={styles.metricValue}>
              {Math.round(session.analysis_data.pace_wpm || 0)} WPM
            </Text>
          </View>
          <View style={styles.metricItem}>
            <Ionicons name="target" size={16} color={COLORS.primary} />
            <Text style={styles.metricValue}>
              {Math.round(session.analysis_data.filler_rate || 0)}% filler
            </Text>
          </View>
          <View style={styles.metricItem}>
            <Ionicons name="sparkles" size={16} color={COLORS.primary} />
            <Text style={styles.metricValue}>
              {Math.round(session.analysis_data.clarity_score || 0)}% clarity
            </Text>
          </View>
        </View>
      )}

      {/* Action Buttons */}
      <View style={styles.actions}>
        {session.completed && (
          <TouchableOpacity
            style={styles.actionButton}
            onPress={handleViewDetails}
            activeOpacity={0.7}
          >
            <Text style={styles.actionButtonText}>View Details</Text>
          </TouchableOpacity>
        )}
        {onDelete && (
          <TouchableOpacity
            style={[styles.actionButton, styles.deleteButton]}
            onPress={handleDelete}
            activeOpacity={0.7}
          >
            <Ionicons name="trash-outline" size={16} color={COLORS.danger} />
            <Text style={[styles.actionButtonText, styles.deleteButtonText]}>Delete</Text>
          </TouchableOpacity>
        )}
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
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: SPACING.xs,
  },
  headerLeft: {
    flex: 1,
    marginRight: SPACING.sm,
  },
  title: {
    fontSize: 16,
    fontWeight: '600',
    color: COLORS.text,
    marginBottom: 2,
  },
  dateText: {
    fontSize: 12,
    color: COLORS.textSecondary,
  },
  statusBadge: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 6,
  },
  statusText: {
    fontSize: 10,
    fontWeight: '700',
  },
  languageBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    alignSelf: 'flex-start',
    paddingHorizontal: 8,
    paddingVertical: 4,
    backgroundColor: COLORS.background,
    borderRadius: 6,
    marginBottom: SPACING.sm,
  },
  languageText: {
    fontSize: 11,
    fontWeight: '600',
    color: COLORS.textSecondary,
  },
  metricsRow: {
    flexDirection: 'row',
    gap: SPACING.md,
    marginBottom: SPACING.sm,
    paddingVertical: SPACING.xs,
    borderTopWidth: 1,
    borderTopColor: COLORS.border,
  },
  metricItem: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  metricValue: {
    fontSize: 13,
    fontWeight: '600',
    color: COLORS.text,
  },
  actions: {
    flexDirection: 'row',
    gap: SPACING.xs,
    marginTop: SPACING.xs,
  },
  actionButton: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 4,
    paddingVertical: 8,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: COLORS.primary,
  },
  actionButtonText: {
    fontSize: 13,
    fontWeight: '600',
    color: COLORS.primary,
  },
  deleteButton: {
    borderColor: COLORS.danger,
  },
  deleteButtonText: {
    color: COLORS.danger,
  },
});
