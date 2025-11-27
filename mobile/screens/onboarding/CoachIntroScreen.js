import React, { useEffect } from 'react';
import { View, Text, StyleSheet, ScrollView, Image } from 'react-native';
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

// Animated feature card with mock preview
function AnimatedFeatureCard({ icon, title, description, mockPreview, index }) {
  const translateY = useSharedValue(100);
  const opacity = useSharedValue(0);
  const scale = useSharedValue(animationValues.scaleStart);

  useEffect(() => {
    const delay = index * staggerDelays.medium;

    translateY.value = withDelay(
      delay,
      withSpring(0, springConfigs.moderate)
    );

    opacity.value = withDelay(
      delay,
      withSpring(1, springConfigs.moderate)
    );

    scale.value = withDelay(
      delay,
      withSpring(animationValues.scaleEnd, springConfigs.moderate)
    );
  }, []);

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [
      { translateY: translateY.value },
      { scale: scale.value }
    ],
    opacity: opacity.value,
  }));

  return (
    <Animated.View style={[styles.featureCard, animatedStyle]}>
      <View style={styles.featureHeader}>
        <View style={styles.iconContainer}>
          <Image source={icon} style={styles.iconImage} resizeMode="contain" />
        </View>
        <View style={styles.featureHeaderText}>
          <Text style={styles.featureTitle}>{title}</Text>
          <Text style={styles.featureDescription}>{description}</Text>
        </View>
      </View>

      {mockPreview}
    </Animated.View>
  );
}

// Mock session recommendation preview
function MockSessionRecommendation() {
  return (
    <View style={styles.mockCard}>
      <Text style={styles.mockTitle}>Reduce Filler Words</Text>
      <View style={styles.mockMetricRow}>
        <View>
          <Text style={styles.mockMetricLabel}>5-Session Avg</Text>
          <Text style={styles.mockMetricValue}>8.2%</Text>
        </View>
        <View style={styles.mockArrow}>
          <Text style={styles.mockArrowText}>→</Text>
        </View>
        <View>
          <Text style={styles.mockMetricLabel}>Goal</Text>
          <Text style={styles.mockMetricValueGoal}>3.0%</Text>
        </View>
      </View>
      <Text style={styles.mockDescription}>
        You use "um" and "like" frequently. Let's reduce these.
      </Text>
    </View>
  );
}

// Mock weekly goal preview
function MockWeeklyGoal() {
  return (
    <View style={styles.mockCard}>
      <Text style={styles.mockTitle}>Reduce Filler Words</Text>
      <Text style={styles.mockTip}>
        Pause briefly instead of saying "um" or "like"
      </Text>
      <View style={styles.mockProgressRow}>
        <View style={styles.mockProgressItem}>
          <Text style={styles.mockProgressLabel}>Today</Text>
          <Text style={styles.mockProgressValue}>2/3 sessions</Text>
        </View>
        <View style={styles.mockProgressItem}>
          <Text style={styles.mockProgressLabel}>Week</Text>
          <Text style={styles.mockProgressValue}>8/15 sessions</Text>
        </View>
      </View>
      <View style={styles.mockStreakContainer}>
        <Text style={styles.mockStreakText}>4 day streak</Text>
      </View>
    </View>
  );
}

// Mock daily drill preview
function MockDailyDrill() {
  return (
    <View style={styles.mockCard}>
      <View style={styles.mockDrillHeader}>
        <View style={styles.mockOrderBadge}>
          <Text style={styles.mockOrderText}>1</Text>
        </View>
        <View style={styles.mockDurationBadge}>
          <Text style={styles.mockDurationText}>60s</Text>
        </View>
      </View>
      <Text style={styles.mockDrillTitle}>Pause Practice</Text>
      <Text style={styles.mockDrillDescription}>
        Practice using intentional pauses instead of filler words. Read a passage aloud, focusing on brief pauses.
      </Text>
      <Text style={styles.mockDrillReason}>
        Based on your filler word usage
      </Text>
    </View>
  );
}

// Animated closing message
function AnimatedClosingMessage() {
  const opacity = useSharedValue(0);

  useEffect(() => {
    const delay = 3 * staggerDelays.medium;
    opacity.value = withDelay(
      delay,
      withSpring(1, springConfigs.moderate)
    );
  }, []);

  const animatedStyle = useAnimatedStyle(() => ({
    opacity: opacity.value,
  }));

  return (
    <Animated.View style={[styles.closingCard, animatedStyle]}>
      <Text style={styles.closingText}>
        Personalized guidance every day
      </Text>
    </Animated.View>
  );
}

export default function CoachIntroScreen({ navigation }) {
  const features = [
    {
      icon: require('../../assets/icons/session-recommendation.png'),
      title: 'Session Recommendations',
      description: 'After each practice session, get personalized insights based on your rolling 5-session average',
      mockPreview: <MockSessionRecommendation />
    },
    {
      icon: require('../../assets/icons/weekly-goal.png'),
      title: 'Weekly Goal',
      description: 'Stay focused on one key area each week with daily and weekly session targets',
      mockPreview: <MockWeeklyGoal />
    },
    {
      icon: require('../../assets/icons/todays-focus.png'),
      title: 'Today\'s Focus',
      description: 'Get personalized daily drills tailored to your specific needs and progress',
      mockPreview: <MockDailyDrill />
    }
  ];

  return (
    <View style={styles.container}>
      <AnimatedBackground />
      <QuitOnboardingButton />
      <ScrollView
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}
      >
        <Text style={styles.header}>How You Will Improve</Text>
        <Text style={styles.subheader}>
          Your personalized AI coach guides you every step of the way
        </Text>

        {features.map((feature, index) => (
          <AnimatedFeatureCard
            key={index}
            icon={feature.icon}
            title={feature.title}
            description={feature.description}
            mockPreview={feature.mockPreview}
            index={index}
          />
        ))}

        <AnimatedClosingMessage />
      </ScrollView>

      <OnboardingNavigation
        currentStep={5}
        totalSteps={12}
        onContinue={() => navigation.navigate('ProgressIntro')}
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
    marginBottom: SPACING.xs,
    lineHeight: 36,
  },
  subheader: {
    fontSize: 16,
    fontWeight: '400',
    color: COLORS.textSecondary,
    textAlign: 'center',
    marginBottom: SPACING.xl,
    lineHeight: 22,
  },
  featureCard: {
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
    shadowOpacity: 0.08,
    shadowRadius: 8,
    elevation: 3,
  },
  featureHeader: {
    flexDirection: 'row',
    marginBottom: SPACING.md,
  },
  iconContainer: {
    width: 48,
    height: 48,
    borderRadius: 24,
    backgroundColor: COLORS.selectedBackground,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: SPACING.md,
  },
  iconImage: {
    width: 36,
    height: 36,
  },
  featureHeaderText: {
    flex: 1,
  },
  featureTitle: {
    fontSize: 17,
    fontWeight: '700',
    color: COLORS.text,
    marginBottom: 4,
    lineHeight: 22,
  },
  featureDescription: {
    fontSize: 14,
    fontWeight: '400',
    color: COLORS.textSecondary,
    lineHeight: 20,
  },
  mockCard: {
    backgroundColor: COLORS.background,
    borderRadius: 12,
    padding: SPACING.md,
    borderWidth: 1,
    borderColor: COLORS.border,
  },
  mockTitle: {
    fontSize: 16,
    fontWeight: '700',
    color: COLORS.text,
    marginBottom: SPACING.xs,
    lineHeight: 20,
  },
  mockTip: {
    fontSize: 13,
    fontWeight: '400',
    color: COLORS.textSecondary,
    marginBottom: SPACING.md,
    lineHeight: 18,
  },
  mockMetricRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: SPACING.sm,
    paddingVertical: SPACING.xs,
  },
  mockMetricLabel: {
    fontSize: 11,
    fontWeight: '500',
    color: COLORS.textMuted,
    textTransform: 'uppercase',
    letterSpacing: 0.5,
    marginBottom: 2,
  },
  mockMetricValue: {
    fontSize: 20,
    fontWeight: '700',
    color: COLORS.text,
  },
  mockMetricValueGoal: {
    fontSize: 20,
    fontWeight: '700',
    color: COLORS.primary,
  },
  mockArrow: {
    paddingHorizontal: SPACING.sm,
  },
  mockArrowText: {
    fontSize: 20,
    color: COLORS.textMuted,
  },
  mockDescription: {
    fontSize: 13,
    fontWeight: '400',
    color: COLORS.textSecondary,
    lineHeight: 18,
  },
  mockProgressRow: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    marginBottom: SPACING.sm,
  },
  mockProgressItem: {
    alignItems: 'center',
  },
  mockProgressLabel: {
    fontSize: 12,
    fontWeight: '500',
    color: COLORS.textMuted,
    marginBottom: 4,
  },
  mockProgressValue: {
    fontSize: 15,
    fontWeight: '700',
    color: COLORS.text,
  },
  mockStreakContainer: {
    backgroundColor: COLORS.selectedBackground,
    borderRadius: 8,
    paddingVertical: SPACING.xs,
    paddingHorizontal: SPACING.sm,
    alignItems: 'center',
  },
  mockStreakText: {
    fontSize: 13,
    fontWeight: '600',
    color: COLORS.primary,
  },
  mockDrillHeader: {
    flexDirection: 'row',
    marginBottom: SPACING.xs,
  },
  mockOrderBadge: {
    backgroundColor: COLORS.primary,
    width: 24,
    height: 24,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: SPACING.xs,
  },
  mockOrderText: {
    fontSize: 13,
    fontWeight: '700',
    color: COLORS.cardBackground,
  },
  mockDurationBadge: {
    backgroundColor: COLORS.background,
    paddingHorizontal: SPACING.sm,
    paddingVertical: 2,
    borderRadius: 6,
    borderWidth: 1,
    borderColor: COLORS.border,
  },
  mockDurationText: {
    fontSize: 11,
    fontWeight: '600',
    color: COLORS.textSecondary,
  },
  mockDrillTitle: {
    fontSize: 16,
    fontWeight: '700',
    color: COLORS.text,
    marginBottom: SPACING.xs,
    lineHeight: 20,
  },
  mockDrillDescription: {
    fontSize: 13,
    fontWeight: '400',
    color: COLORS.textSecondary,
    marginBottom: SPACING.sm,
    lineHeight: 18,
  },
  mockDrillReason: {
    fontSize: 12,
    fontWeight: '500',
    color: COLORS.primary,
    fontStyle: 'italic',
    lineHeight: 16,
  },
  closingCard: {
    backgroundColor: COLORS.selectedBackground,
    borderRadius: 12,
    padding: SPACING.lg,
    marginBottom: SPACING.md,
    borderWidth: 1,
    borderColor: COLORS.primary,
  },
  closingText: {
    fontSize: 15,
    fontWeight: '500',
    color: COLORS.text,
    textAlign: 'center',
    lineHeight: 22,
  },
});
