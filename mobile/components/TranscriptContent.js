import React, { useState } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ScrollView } from 'react-native';
import { COLORS, SPACING } from '../constants/colors';

/**
 * TranscriptContent Component
 * Displays highlighted transcript with filler word highlighting
 *
 * @param {string} transcript - Raw transcript text
 * @param {Array} issues - Array of issue objects with filler word highlights
 */
export default function TranscriptContent({ transcript = '', issues = [] }) {
  const [showHighlights, setShowHighlights] = useState(true);
  const [showColorKey, setShowColorKey] = useState(false);

  // Define filler word colors
  const fillerColors = {
    filler_um: { color: '#FF6B6B', label: 'um, uh' },
    filler_like: { color: '#FFB347', label: 'like' },
    filler_you_know: { color: '#FFE66D', label: 'you know' },
    filler_basically: { color: '#C68FE6', label: 'basically, actually' },
  };

  // Get filler words from issues
  // coaching_note contains the actual filler word (e.g., "um", "like")
  const fillerWords = issues
    .filter((issue) => issue.category === 'filler_words')
    .map((issue) => ({
      text: issue.coaching_note || issue.text, // Use coaching_note (isolated word) if available
      start_ms: issue.start_ms,
      end_ms: issue.end_ms,
      type: issue.coaching_note?.filler_type || 'filler_um',
    }))
    .filter((filler) => filler.text); // Filter out entries without text

  // Helper function to escape regex special characters
  const escapeRegex = (str) => {
    return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  };

  // Function to highlight filler words in transcript
  const highlightTranscript = () => {
    if (!showHighlights || fillerWords.length === 0) {
      return <Text style={styles.transcriptText}>{transcript}</Text>;
    }

    // Create array of all filler word matches with word boundaries
    const allMatches = [];

    fillerWords.forEach((filler) => {
      // Escape special regex characters and create word boundary pattern
      const escapedText = escapeRegex(filler.text);
      const pattern = new RegExp(`\\b${escapedText}\\b`, 'gi');

      let match;
      while ((match = pattern.exec(transcript)) !== null) {
        allMatches.push({
          index: match.index,
          length: match[0].length,
          text: match[0],
          color: fillerColors[filler.type]?.color || fillerColors.filler_um.color,
        });
      }
    });

    // Sort matches by index
    allMatches.sort((a, b) => a.index - b.index);

    // Remove overlapping matches (keep first occurrence)
    const nonOverlappingMatches = [];
    let lastEnd = 0;
    allMatches.forEach((match) => {
      if (match.index >= lastEnd) {
        nonOverlappingMatches.push(match);
        lastEnd = match.index + match.length;
      }
    });

    // Build segments from matches
    const segments = [];
    let lastIndex = 0;

    nonOverlappingMatches.forEach((match) => {
      // Add text before match
      if (match.index > lastIndex) {
        segments.push({
          text: transcript.substring(lastIndex, match.index),
          isHighlight: false,
        });
      }

      // Add highlighted match
      segments.push({
        text: match.text,
        isHighlight: true,
        color: match.color,
      });

      lastIndex = match.index + match.length;
    });

    // Add remaining text
    if (lastIndex < transcript.length) {
      segments.push({
        text: transcript.substring(lastIndex),
        isHighlight: false,
      });
    }

    return (
      <Text style={styles.transcriptText}>
        {segments.map((segment, index) =>
          segment.isHighlight ? (
            <Text
              key={index}
              style={[
                styles.highlightedText,
                { backgroundColor: segment.color + '40' },
              ]}
            >
              {segment.text}
            </Text>
          ) : (
            <Text key={index}>{segment.text}</Text>
          )
        )}
      </Text>
    );
  };

  if (!transcript || transcript.trim() === '') {
    return (
      <View style={styles.emptyContainer}>
        <Text style={styles.emptyText}>No transcript available</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      {/* Controls */}
      <View style={styles.controls}>
        <TouchableOpacity
          style={styles.toggleButton}
          onPress={() => setShowHighlights(!showHighlights)}
        >
          <Text style={styles.toggleButtonText}>
            {showHighlights ? '🎨 Hide Highlights' : '🎨 Show Highlights'}
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={styles.toggleButton}
          onPress={() => setShowColorKey(!showColorKey)}
        >
          <Text style={styles.toggleButtonText}>
            {showColorKey ? '📖 Hide Key' : '📖 Color Key'}
          </Text>
        </TouchableOpacity>
      </View>

      {/* Color Key */}
      {showColorKey && (
        <View style={styles.colorKey}>
          <Text style={styles.colorKeyTitle}>Highlight Colors:</Text>
          {Object.entries(fillerColors).map(([key, value]) => (
            <View key={key} style={styles.colorKeyItem}>
              <View
                style={[
                  styles.colorKeyDot,
                  { backgroundColor: value.color },
                ]}
              />
              <Text style={styles.colorKeyLabel}>{value.label}</Text>
            </View>
          ))}
        </View>
      )}

      {/* Transcript */}
      <ScrollView
        style={styles.transcriptContainer}
        nestedScrollEnabled={true}
      >
        {highlightTranscript()}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  controls: {
    flexDirection: 'row',
    gap: SPACING.xs,
    marginBottom: SPACING.md,
  },
  toggleButton: {
    flex: 1,
    backgroundColor: COLORS.background,
    paddingVertical: SPACING.xs,
    paddingHorizontal: SPACING.sm,
    borderRadius: 8,
    alignItems: 'center',
  },
  toggleButtonText: {
    fontSize: 13,
    fontWeight: '600',
    color: COLORS.text,
  },
  colorKey: {
    backgroundColor: COLORS.background,
    borderRadius: 12,
    padding: SPACING.sm,
    marginBottom: SPACING.md,
  },
  colorKeyTitle: {
    fontSize: 13,
    fontWeight: '600',
    color: COLORS.text,
    marginBottom: SPACING.xs,
  },
  colorKeyItem: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: SPACING.xs,
  },
  colorKeyDot: {
    width: 12,
    height: 12,
    borderRadius: 6,
    marginRight: SPACING.xs,
  },
  colorKeyLabel: {
    fontSize: 13,
    color: COLORS.textSecondary,
  },
  transcriptContainer: {
    maxHeight: 400,
    backgroundColor: COLORS.background,
    borderRadius: 12,
    padding: SPACING.md,
  },
  transcriptText: {
    fontSize: 15,
    lineHeight: 24,
    color: COLORS.text,
  },
  highlightedText: {
    fontWeight: '600',
    borderRadius: 4,
    paddingHorizontal: 2,
  },
  emptyContainer: {
    alignItems: 'center',
    paddingVertical: SPACING.xl,
  },
  emptyText: {
    fontSize: 14,
    color: COLORS.textSecondary,
  },
});
