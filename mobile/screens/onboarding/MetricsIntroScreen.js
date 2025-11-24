import React, { useEffect } from 'react';
import { View, Text, StyleSheet, ScrollView } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
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

// Animated card component for main metrics
function AnimatedMetricCard({ icon, title, description, index }) {
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
    <Animated.View style={[styles.mainCard, animatedStyle]}>
      <View style={styles.iconContainer}>
        <Ionicons name={icon} size={24} color={COLORS.primary} />
      </View>
      <View style={styles.mainCardContent}>
        <Text style={styles.mainCardTitle}>{title}</Text>
        <Text style={styles.mainCardDescription}>{description}</Text>
      </View>
    </Animated.View>
  );
}

// Animated component for secondary metrics
function AnimatedSecondaryMetric({ title, tagline, index }) {
  const translateY = useSharedValue(100);
  const opacity = useSharedValue(0);

  useEffect(() => {
    // Delay after main metrics (3 * medium delay + additional offset)
    const delay = (3 + index) * staggerDelays.medium;

    translateY.value = withDelay(
      delay,
      withSpring(0, springConfigs.moderate)
    );

    opacity.value = withDelay(
      delay,
      withSpring(1, springConfigs.moderate)
    );
  }, []);

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ translateY: translateY.value }],
    opacity: opacity.value,
  }));

  return (
    <Animated.View style={[styles.secondaryMetric, animatedStyle]}>
      <Text style={styles.secondaryTitle}>{title}</Text>
      <Text style={styles.secondaryTagline}>{tagline}</Text>
    </Animated.View>
  );
}

export default function MetricsIntroScreen({ navigation }) {
  const mainMetrics = [
    {
      icon: 'target-outline',
      title: 'Clarity Score',
      description: 'How clearly you articulate words'
    },
    {
      icon: 'close-circle-outline',
      title: 'Filler Words',
      description: 'Track "um", "uh", "like"'
    },
    {
      icon: 'speedometer-outline',
      title: 'Speaking Pace',
      description: 'Your optimal speaking speed'
    }
  ];

  const secondaryMetrics = [
    {
      title: 'Pace Consistency',
      tagline: 'How steady your speaking rhythm stays'
    },
    {
      title: 'Fluency Score',
      tagline: 'How smoothly your speech flows'
    },
    {
      title: 'Engagement Score',
      tagline: 'How dynamic your delivery is'
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
        <Text style={styles.header}>What You Will Improve</Text>
        <Text style={styles.subheader}>
          Track these key metrics to transform your speaking
        </Text>

        {/* Main Metrics */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Main Metrics</Text>
          {mainMetrics.map((metric, index) => (
            <AnimatedMetricCard
              key={index}
              icon={metric.icon}
              title={metric.title}
              description={metric.description}
              index={index}
            />
          ))}
        </View>

        {/* Secondary Metrics */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Also Tracked</Text>
          {secondaryMetrics.map((metric, index) => (
            <AnimatedSecondaryMetric
              key={index}
              title={metric.title}
              tagline={metric.tagline}
              index={index}
            />
          ))}
        </View>
      </ScrollView>

      <OnboardingNavigation
        currentStep={3}
        totalSteps={12}
        onContinue={() => navigation.navigate('OverallScore')}
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
  section: {
    marginBottom: SPACING.xl,
  },
  sectionTitle: {
    fontSize: 17,
    fontWeight: '600',
    color: COLORS.text,
    marginBottom: SPACING.md,
    lineHeight: 22,
  },
  mainCard: {
    backgroundColor: COLORS.cardBackground,
    borderRadius: 16,
    borderWidth: 1,
    borderColor: COLORS.border,
    padding: SPACING.lg,
    marginBottom: SPACING.md,
    flexDirection: 'row',
    alignItems: 'center',
    shadowColor: COLORS.text,
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.08,
    shadowRadius: 8,
    elevation: 3,
  },
  iconContainer: {
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: COLORS.selectedBackground,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: SPACING.md,
  },
  mainCardContent: {
    flex: 1,
  },
  mainCardTitle: {
    fontSize: 17,
    fontWeight: '700',
    color: COLORS.text,
    marginBottom: 4,
    lineHeight: 22,
  },
  mainCardDescription: {
    fontSize: 14,
    fontWeight: '400',
    color: COLORS.textSecondary,
    lineHeight: 20,
  },
  secondaryMetric: {
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
  secondaryTitle: {
    fontSize: 15,
    fontWeight: '600',
    color: COLORS.text,
    marginBottom: 4,
    lineHeight: 20,
  },
  secondaryTagline: {
    fontSize: 13,
    fontWeight: '400',
    color: COLORS.textSecondary,
    lineHeight: 18,
  },
});
