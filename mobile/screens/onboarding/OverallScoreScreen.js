import React, { useEffect } from 'react';
import { View, Text, StyleSheet, ScrollView } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
  withDelay
} from 'react-native-reanimated';
import OnboardingNavigation from '../../components/OnboardingNavigation';
import AnimatedBackground from '../../components/AnimatedBackground';
import QuitOnboardingButton from '../../components/QuitOnboardingButton';
import { COLORS, SPACING } from '../../constants/colors';
import { springConfigs, staggerDelays, animationValues } from '../../utils/animationConfigs';

// Animated metric weights display
function AnimatedMetricWeights() {
  const opacity = useSharedValue(0);
  const scale = useSharedValue(animationValues.scaleStart);

  useEffect(() => {
    scale.value = withSpring(animationValues.scaleEnd, springConfigs.bouncy);
    opacity.value = withSpring(1, springConfigs.bouncy);
  }, []);

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
    opacity: opacity.value,
  }));

  const metrics = [
    { name: 'Clarity', weight: 25 },
    { name: 'Filler Words', weight: 20 },
    { name: 'Speaking Pace', weight: 20 },
    { name: 'Fluency', weight: 15 },
    { name: 'Engagement', weight: 12 },
    { name: 'Pause Quality', weight: 8 },
  ];

  return (
    <Animated.View style={[styles.metricsWeightCard, animatedStyle]}>
      <Text style={styles.metricsWeightTitle}>How It's Calculated</Text>
      {metrics.map((metric, index) => (
        <View key={index} style={styles.metricWeightRow}>
          <Text style={styles.metricName}>{metric.name}</Text>
          <Text style={styles.metricWeight}>{metric.weight}%</Text>
        </View>
      ))}
    </Animated.View>
  );
}

// Animated grade chart
function AnimatedGradeChart() {
  const opacity = useSharedValue(0);

  useEffect(() => {
    const delay = 4 * staggerDelays.medium;
    opacity.value = withDelay(
      delay,
      withSpring(1, springConfigs.moderate)
    );
  }, []);

  const animatedStyle = useAnimatedStyle(() => ({
    opacity: opacity.value,
  }));

  const grades = [
    { letter: 'A+', range: '97-100%', color: COLORS.success },
    { letter: 'A', range: '93-96%', color: COLORS.success },
    { letter: 'A-', range: '90-92%', color: COLORS.success },
    { letter: 'B', range: '80-89%', color: COLORS.textSecondary },
    { letter: 'C', range: '70-79%', color: COLORS.warning },
    { letter: 'D', range: 'Below 70%', color: COLORS.danger },
  ];

  return (
    <Animated.View style={[styles.gradeChart, animatedStyle]}>
      <Text style={styles.chartTitle}>Letter Grade Scale</Text>
      <View style={styles.gradePillsContainer}>
        {grades.map((grade, index) => (
          <View key={index} style={styles.gradePill}>
            <Text style={[styles.gradePillLetter, { color: grade.color }]}>
              {grade.letter}
            </Text>
            <Text style={styles.gradePillRange}>{grade.range}</Text>
          </View>
        ))}
      </View>
    </Animated.View>
  );
}

export default function OverallScoreScreen({ navigation }) {
  return (
    <View style={styles.container}>
      <AnimatedBackground />
      <QuitOnboardingButton />
      <ScrollView
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}
      >
        <Text style={styles.header}>Your Most Important Metric</Text>

        <View style={styles.overallScoreIntro}>
          <Text style={styles.overallScoreTitle}>Overall Score</Text>
          <Text style={styles.overallScoreDescription}>
            One number for your overall speaking performance
          </Text>
        </View>

        <AnimatedMetricWeights />

        <AnimatedGradeChart />
      </ScrollView>

      <OnboardingNavigation
        currentStep={4}
        totalSteps={12}
        onContinue={() => navigation.navigate('CoachIntro')}
      />
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
    paddingBottom: 180,
  },
  header: {
    fontSize: 28,
    fontWeight: 'bold',
    color: COLORS.text,
    textAlign: 'center',
    marginBottom: SPACING.lg,
    lineHeight: 36,
  },
  overallScoreIntro: {
    alignItems: 'center',
    marginBottom: SPACING.xl,
  },
  overallScoreTitle: {
    fontSize: 32,
    fontWeight: 'bold',
    color: COLORS.primary,
    marginBottom: 4,
    lineHeight: 40,
  },
  overallScoreDescription: {
    fontSize: 15,
    fontWeight: '400',
    color: COLORS.textSecondary,
    textAlign: 'center',
    lineHeight: 22,
  },
  metricsWeightCard: {
    backgroundColor: COLORS.cardBackground,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: COLORS.border,
    padding: SPACING.lg,
    marginBottom: SPACING.md,
    shadowColor: COLORS.text,
    shadowOffset: {
      width: 0,
      height: 1,
    },
    shadowOpacity: 0.05,
    shadowRadius: 3,
    elevation: 2,
  },
  metricsWeightTitle: {
    fontSize: 17,
    fontWeight: '700',
    color: COLORS.text,
    marginBottom: SPACING.md,
    lineHeight: 22,
  },
  metricWeightRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: SPACING.sm,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border,
  },
  metricName: {
    fontSize: 15,
    fontWeight: '500',
    color: COLORS.text,
    lineHeight: 20,
  },
  metricWeight: {
    fontSize: 15,
    fontWeight: '700',
    color: COLORS.primary,
    lineHeight: 20,
  },
  gradeChart: {
    backgroundColor: COLORS.cardBackground,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: COLORS.border,
    padding: SPACING.lg,
    marginBottom: SPACING.md,
    shadowColor: COLORS.text,
    shadowOffset: {
      width: 0,
      height: 1,
    },
    shadowOpacity: 0.05,
    shadowRadius: 3,
    elevation: 2,
  },
  chartTitle: {
    fontSize: 15,
    fontWeight: '600',
    color: COLORS.text,
    marginBottom: SPACING.md,
    textAlign: 'center',
  },
  gradePillsContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
  },
  gradePill: {
    width: '31%',
    backgroundColor: COLORS.background,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: COLORS.border,
    paddingVertical: SPACING.sm,
    paddingHorizontal: SPACING.xs,
    marginBottom: SPACING.sm,
    alignItems: 'center',
  },
  gradePillLetter: {
    fontSize: 18,
    fontWeight: '700',
    marginBottom: 2,
  },
  gradePillRange: {
    fontSize: 12,
    fontWeight: '500',
    color: COLORS.textSecondary,
    textAlign: 'center',
  },
});
