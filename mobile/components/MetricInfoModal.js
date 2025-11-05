import React from 'react';
import { View, Text, StyleSheet, Modal, TouchableOpacity, ScrollView } from 'react-native';
import { COLORS, SPACING } from '../constants/colors';

/**
 * MetricInfoModal Component
 * Modal that explains what each metric measures and how to improve it
 *
 * @param {boolean} visible - Whether modal is visible
 * @param {string} metricType - Type of metric ('overall', 'clarity', 'filler', 'wpm')
 * @param {function} onClose - Callback when modal is closed
 */
export default function MetricInfoModal({ visible, metricType, onClose }) {
  // Define metric information
  const metricInfo = {
    overall: {
      title: 'Overall Score',
      icon: '🎯',
      description: 'Your overall speaking performance score based on all metrics.',
      whatItMeasures: [
        'Clarity of speech',
        'Filler word usage',
        'Speaking pace',
        'Fluency and engagement',
        'Pause quality',
      ],
      idealRange: '80-100% (A- to A+)',
      howToImprove: [
        'Practice speaking on various topics daily',
        'Focus on your weakest individual metrics',
        'Record yourself regularly to track progress',
        'Work through targeted drills for specific areas',
      ],
    },
    clarity: {
      title: 'Clarity Score',
      icon: '🔊',
      description: 'How clearly and understandably you speak.',
      whatItMeasures: [
        'Pronunciation quality',
        'Articulation of words',
        'Volume consistency',
        'Speech intelligibility',
      ],
      idealRange: '85-100% (Very Clear)',
      howToImprove: [
        'Speak slowly and enunciate each word clearly',
        'Practice tongue twisters to improve articulation',
        'Record and listen back to identify unclear words',
        'Read aloud for 10 minutes daily',
      ],
    },
    filler: {
      title: 'Filler Percentage',
      icon: '🚫',
      description: 'Percentage of your speech that consists of filler words.',
      whatItMeasures: [
        'Frequency of "um", "uh", "like"',
        'Use of "you know", "basically"',
        'Other verbal fillers',
        'Impact on speech flow',
      ],
      idealRange: 'Below 3% (Professional)',
      howToImprove: [
        'Pause silently instead of saying "um"',
        'Practice the 1-2 second pause drill',
        'Record yourself and count fillers',
        'Speak slower to give yourself time to think',
      ],
    },
    wpm: {
      title: 'Words Per Minute',
      icon: '⚡',
      description: 'Your speaking pace measured in words per minute.',
      whatItMeasures: [
        'Speaking speed',
        'Pace variation',
        'Time between words',
        'Overall tempo',
      ],
      idealRange: '130-170 WPM (Natural)',
      howToImprove: [
        'Practice speaking at different speeds',
        'Use a metronome to maintain consistent pace',
        'Read aloud at your target WPM',
        'Vary your pace for emphasis and engagement',
      ],
    },
  };

  const info = metricInfo[metricType] || metricInfo.overall;

  return (
    <Modal
      visible={visible}
      transparent={true}
      animationType="slide"
      onRequestClose={onClose}
    >
      <View style={styles.overlay}>
        <View style={styles.modalContainer}>
          {/* Header */}
          <View style={styles.header}>
            <View style={styles.headerLeft}>
              <Text style={styles.icon}>{info.icon}</Text>
              <Text style={styles.title}>{info.title}</Text>
            </View>
            <TouchableOpacity onPress={onClose} style={styles.closeButton}>
              <Text style={styles.closeButtonText}>✕</Text>
            </TouchableOpacity>
          </View>

          <ScrollView
            style={styles.content}
            showsVerticalScrollIndicator={false}
          >
            {/* Description */}
            <Text style={styles.description}>{info.description}</Text>

            {/* What It Measures */}
            <View style={styles.section}>
              <Text style={styles.sectionTitle}>What it measures:</Text>
              {info.whatItMeasures.map((item, index) => (
                <View key={index} style={styles.listItem}>
                  <Text style={styles.bullet}>•</Text>
                  <Text style={styles.listItemText}>{item}</Text>
                </View>
              ))}
            </View>

            {/* Ideal Range */}
            <View style={styles.section}>
              <Text style={styles.sectionTitle}>Ideal range:</Text>
              <View style={styles.idealRangeBox}>
                <Text style={styles.idealRangeText}>{info.idealRange}</Text>
              </View>
            </View>

            {/* How to Improve */}
            <View style={styles.section}>
              <Text style={styles.sectionTitle}>How to improve:</Text>
              {info.howToImprove.map((tip, index) => (
                <View key={index} style={styles.tipItem}>
                  <View style={styles.tipNumber}>
                    <Text style={styles.tipNumberText}>{index + 1}</Text>
                  </View>
                  <Text style={styles.tipText}>{tip}</Text>
                </View>
              ))}
            </View>
          </ScrollView>

          {/* Close Button */}
          <TouchableOpacity style={styles.bottomButton} onPress={onClose}>
            <Text style={styles.bottomButtonText}>Got it!</Text>
          </TouchableOpacity>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'flex-end',
  },
  modalContainer: {
    backgroundColor: COLORS.background,
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
    maxHeight: '85%',
    paddingTop: SPACING.lg,
    paddingHorizontal: SPACING.lg,
    paddingBottom: SPACING.xl,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.lg,
  },
  headerLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  icon: {
    fontSize: 32,
    marginRight: SPACING.sm,
  },
  title: {
    fontSize: 24,
    fontWeight: '700',
    color: COLORS.text,
  },
  closeButton: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: COLORS.cardBackground,
    justifyContent: 'center',
    alignItems: 'center',
  },
  closeButtonText: {
    fontSize: 20,
    color: COLORS.textSecondary,
  },
  content: {
    marginBottom: SPACING.lg,
  },
  description: {
    fontSize: 16,
    color: COLORS.textSecondary,
    lineHeight: 24,
    marginBottom: SPACING.lg,
  },
  section: {
    marginBottom: SPACING.lg,
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: '700',
    color: COLORS.text,
    marginBottom: SPACING.sm,
  },
  listItem: {
    flexDirection: 'row',
    marginTop: SPACING.xs,
  },
  bullet: {
    fontSize: 16,
    color: COLORS.primary,
    marginRight: SPACING.xs,
    marginTop: 2,
  },
  listItemText: {
    flex: 1,
    fontSize: 15,
    color: COLORS.textSecondary,
    lineHeight: 22,
  },
  idealRangeBox: {
    backgroundColor: COLORS.primary + '20',
    padding: SPACING.md,
    borderRadius: 12,
    borderLeftWidth: 4,
    borderLeftColor: COLORS.primary,
  },
  idealRangeText: {
    fontSize: 18,
    fontWeight: '700',
    color: COLORS.primary,
  },
  tipItem: {
    flexDirection: 'row',
    marginTop: SPACING.sm,
  },
  tipNumber: {
    width: 24,
    height: 24,
    borderRadius: 12,
    backgroundColor: COLORS.primary,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: SPACING.sm,
    marginTop: 2,
  },
  tipNumberText: {
    fontSize: 12,
    fontWeight: '700',
    color: COLORS.white,
  },
  tipText: {
    flex: 1,
    fontSize: 15,
    color: COLORS.textSecondary,
    lineHeight: 22,
  },
  bottomButton: {
    backgroundColor: COLORS.primary,
    paddingVertical: SPACING.md,
    borderRadius: 12,
    alignItems: 'center',
  },
  bottomButtonText: {
    fontSize: 16,
    fontWeight: '600',
    color: COLORS.white,
  },
});
