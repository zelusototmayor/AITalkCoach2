import React, { useState } from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity } from 'react-native';
import Button from '../../components/Button';
import MetricCard from '../../components/MetricCard';
import { COLORS, SPACING } from '../../constants/colors';
import { UNLOCK_FEATURES } from '../../constants/onboardingData';
import { useOnboarding } from '../../context/OnboardingContext';

// Helper function to calculate metrics and generate recommendations
function calculateMetrics(results) {
  // Assume 30 second duration and extract word count from mock/real data
  // For trial: ~75 words (150 WPM at 30s = 75 words)
  const estimatedWordCount = Math.round((results.wordsPerMinute || 150) * 0.5); // 30s = 0.5 min

  // Calculate filler words percentage
  const fillerWordsPerMin = results.fillerWordsPerMinute || 8.5;
  const totalFillers = Math.round(fillerWordsPerMin * 0.5); // 30s recording
  const fillerPercentage = ((totalFillers / estimatedWordCount) * 100).toFixed(1);

  // Generate recommendations based on thresholds (matching web app logic)
  const recommendations = [];

  // Filler words recommendation (if >3%)
  if (parseFloat(fillerPercentage) > 3) {
    recommendations.push({
      metric: 'Filler Words',
      message: 'Too high - pause when you don\'t know what to say',
      severity: parseFloat(fillerPercentage) > 5 ? 'high' : 'medium'
    });
  }

  // Pace recommendation (optimal: 140-160 WPM)
  const wpm = results.wordsPerMinute || 145;
  if (wpm < 140) {
    recommendations.push({
      metric: 'Pace',
      message: 'A bit slow - try speaking slightly faster',
      severity: wpm < 120 ? 'high' : 'medium'
    });
  } else if (wpm > 160) {
    recommendations.push({
      metric: 'Pace',
      message: 'A bit fast - slow down to give listeners time to absorb',
      severity: wpm > 180 ? 'high' : 'medium'
    });
  }

  // Clarity recommendation (if <70%)
  const clarity = results.clarity || 72;
  if (clarity < 70) {
    recommendations.push({
      metric: 'Clarity',
      message: 'Focus on articulation and pausing between thoughts',
      severity: clarity < 60 ? 'high' : 'medium'
    });
  }

  return {
    clarity,
    fillerPercentage,
    fillerWordsPerMin,
    wordsPerMinute: wpm,
    recommendations
  };
}

export default function ResultsScreen({ navigation }) {
  const { onboardingData } = useOnboarding();
  const [showTranscript, setShowTranscript] = useState(false);

  // Get results from context (either real or mock data)
  const results = onboardingData.trialResults || {};
  const isMockData = results.isMockData || false;

  // Calculate metrics with recommendations
  const metrics = calculateMetrics(results);

  const handleContinue = () => {
    navigation.navigate('Cinematic');
  };

  return (
    <View style={styles.container}>
      <ScrollView
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}
      >
        <Text style={styles.header}>Great job!</Text>
        <Text style={styles.subheader}>Let's see how you did</Text>

        {/* Mock Data Disclaimer */}
        {isMockData && (
          <View style={styles.mockBadge}>
            <Text style={styles.mockBadgeText}>
              📊 This is example data - record your own to see real results!
            </Text>
          </View>
        )}

        {/* Metrics Grid */}
        <View style={styles.metricsContainer}>
          <MetricCard
            icon="✨"
            label="Clarity"
            value={`${metrics.clarity}%`}
            style={styles.metricCard}
          />
          <MetricCard
            icon="🗣️"
            label="Filler Words"
            value={`${metrics.fillerPercentage}%`}
            style={styles.metricCard}
          />
          <MetricCard
            icon="⚡"
            label="Pace"
            value={`${metrics.wordsPerMinute}`}
            subtitle="WPM"
            style={styles.metricCard}
          />
        </View>

        {/* Recommendations Section */}
        {metrics.recommendations.length > 0 && (
          <View style={styles.recommendationsContainer}>
            <Text style={styles.recommendationsHeader}>Recommendations</Text>
            {metrics.recommendations.map((rec, index) => (
              <View
                key={index}
                style={[
                  styles.recommendationCard,
                  index === metrics.recommendations.length - 1 && styles.lastRecommendationCard
                ]}
              >
                <View style={styles.recommendationHeader}>
                  <Text style={styles.recommendationMetric}>{rec.metric}</Text>
                  <View style={[
                    styles.severityBadge,
                    rec.severity === 'high' && styles.severityHigh
                  ]}>
                    <Text style={styles.severityText}>
                      {rec.severity === 'high' ? 'Priority' : 'Focus'}
                    </Text>
                  </View>
                </View>
                <Text style={styles.recommendationMessage}>{rec.message}</Text>
              </View>
            ))}
          </View>
        )}

        {/* Expandable Transcript */}
        <TouchableOpacity
          style={styles.transcriptToggle}
          onPress={() => setShowTranscript(!showTranscript)}
          activeOpacity={0.7}
        >
          <Text style={styles.transcriptToggleText}>
            See Full Transcript {showTranscript ? '▲' : '▼'}
          </Text>
        </TouchableOpacity>

        {showTranscript && (
          <View style={styles.transcriptContainer}>
            <Text style={styles.transcriptText}>
              {results.transcript || 'No transcript available.'}
            </Text>
          </View>
        )}

        {/* What You'll Unlock Section */}
        <View style={styles.unlockSection}>
          <Text style={styles.unlockHeader}>What You'll Unlock</Text>

          {UNLOCK_FEATURES.map((feature) => (
            <View key={feature.id} style={styles.featureRow}>
              <Text style={styles.featureIcon}>{feature.icon}</Text>
              <View style={styles.featureTextContainer}>
                <Text style={styles.featureTitle}>{feature.title}</Text>
                {feature.subtitle && (
                  <Text style={styles.featureSubtitle}>{feature.subtitle}</Text>
                )}
              </View>
            </View>
          ))}
        </View>

        {/* Pagination dots */}
        <View style={styles.paginationContainer}>
          {[...Array(8)].map((_, index) => (
            <View
              key={index}
              style={[
                styles.dot,
                index === 5 && styles.activeDot, // Screen 6 (Results) is active
              ]}
            />
          ))}
        </View>
      </ScrollView>

      <View style={styles.buttonContainer}>
        <Button
          title="Get Full Access →"
          onPress={handleContinue}
          variant="primary"
          style={styles.button}
        />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background,
  },
  scrollContent: {
    flexGrow: 1,
    paddingHorizontal: SPACING.lg,
    paddingTop: 60,
    paddingBottom: 120,
  },
  header: {
    fontSize: 28,
    fontWeight: 'bold',
    color: COLORS.text,
    textAlign: 'center',
    marginBottom: SPACING.xs,
    lineHeight: 36,
  },
  subheader: {
    fontSize: 16,
    fontWeight: '500',
    color: COLORS.textSecondary,
    textAlign: 'center',
    marginBottom: SPACING.lg,
  },
  mockBadge: {
    backgroundColor: COLORS.accentLight,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: COLORS.accent,
    borderStyle: 'dashed',
    padding: SPACING.md,
    marginBottom: SPACING.lg,
  },
  mockBadgeText: {
    fontSize: 14,
    fontWeight: '600',
    color: COLORS.text,
    textAlign: 'center',
  },
  metricsContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    gap: SPACING.sm,
    marginBottom: SPACING.lg,
  },
  metricCard: {
    flex: 1,
  },
  transcriptToggle: {
    backgroundColor: COLORS.cardBackground,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: COLORS.border,
    paddingVertical: SPACING.md,
    paddingHorizontal: SPACING.lg,
    alignItems: 'center',
    marginBottom: SPACING.md,
  },
  transcriptToggleText: {
    fontSize: 16,
    fontWeight: '600',
    color: COLORS.primary,
  },
  transcriptContainer: {
    backgroundColor: COLORS.cardBackground,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: COLORS.border,
    padding: SPACING.lg,
    marginBottom: SPACING.lg,
  },
  transcriptText: {
    fontSize: 15,
    fontWeight: '400',
    color: COLORS.text,
    lineHeight: 24,
  },
  unlockSection: {
    backgroundColor: COLORS.cardBackground,
    borderRadius: 16,
    borderWidth: 1,
    borderColor: COLORS.border,
    padding: SPACING.lg,
    marginBottom: SPACING.lg,
    shadowColor: COLORS.text,
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.05,
    shadowRadius: 4,
    elevation: 2,
  },
  unlockHeader: {
    fontSize: 18,
    fontWeight: 'bold',
    color: COLORS.text,
    marginBottom: SPACING.md,
  },
  featureRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: SPACING.md,
  },
  featureIcon: {
    fontSize: 24,
    marginRight: SPACING.md,
  },
  featureTextContainer: {
    flex: 1,
  },
  featureTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: COLORS.text,
  },
  featureSubtitle: {
    fontSize: 14,
    fontWeight: '400',
    color: COLORS.textSecondary,
  },
  paginationContainer: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    marginTop: SPACING.xxl,
    gap: SPACING.xs,
  },
  dot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: COLORS.border,
  },
  activeDot: {
    backgroundColor: COLORS.primary,
    width: 24,
    height: 8,
    borderRadius: 4,
  },
  buttonContainer: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    padding: SPACING.lg,
    backgroundColor: COLORS.background,
    borderTopWidth: 1,
    borderTopColor: COLORS.border,
  },
  button: {
    width: '100%',
  },
  recommendationsContainer: {
    backgroundColor: COLORS.cardBackground,
    borderRadius: 16,
    borderWidth: 1,
    borderColor: COLORS.border,
    padding: SPACING.lg,
    marginBottom: SPACING.lg,
    shadowColor: COLORS.text,
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.05,
    shadowRadius: 4,
    elevation: 2,
  },
  recommendationsHeader: {
    fontSize: 18,
    fontWeight: 'bold',
    color: COLORS.text,
    marginBottom: SPACING.md,
  },
  recommendationCard: {
    backgroundColor: COLORS.selectedBackground,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: COLORS.accent,
    padding: SPACING.md,
    marginBottom: SPACING.sm,
  },
  lastRecommendationCard: {
    marginBottom: 0,
  },
  recommendationHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.xs,
  },
  recommendationMetric: {
    fontSize: 15,
    fontWeight: '700',
    color: COLORS.text,
  },
  severityBadge: {
    backgroundColor: COLORS.accent,
    paddingHorizontal: SPACING.sm,
    paddingVertical: 4,
    borderRadius: 8,
  },
  severityHigh: {
    backgroundColor: COLORS.primary,
  },
  severityText: {
    fontSize: 12,
    fontWeight: '600',
    color: COLORS.text,
  },
  recommendationMessage: {
    fontSize: 14,
    fontWeight: '400',
    color: COLORS.text,
    lineHeight: 20,
  },
});
