import React, { useEffect } from 'react';
import { View, Text, StyleSheet, ScrollView, Dimensions } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
  withDelay
} from 'react-native-reanimated';
import { LineChart } from 'react-native-gifted-charts';
import OnboardingNavigation from '../../components/OnboardingNavigation';
import AnimatedBackground from '../../components/AnimatedBackground';
import QuitOnboardingButton from '../../components/QuitOnboardingButton';
import { COLORS, SPACING } from '../../constants/colors';
import { springConfigs, staggerDelays, animationValues } from '../../utils/animationConfigs';

const SCREEN_WIDTH = Dimensions.get('window').width;

// Animated chart container
function AnimatedChartCard() {
  const translateY = useSharedValue(100);
  const opacity = useSharedValue(0);
  const scale = useSharedValue(animationValues.scaleStart);

  useEffect(() => {
    translateY.value = withSpring(0, springConfigs.moderate);
    opacity.value = withSpring(1, springConfigs.moderate);
    scale.value = withSpring(animationValues.scaleEnd, springConfigs.moderate);
  }, []);

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [
      { translateY: translateY.value },
      { scale: scale.value }
    ],
    opacity: opacity.value,
  }));

  // Mock data showing improvement trend (filler words decreasing)
  const mockData = [
    { value: 8.2, label: 'Mon', dataPointText: '8.2%' },
    { value: 7.5, label: 'Tue', dataPointText: '7.5%' },
    { value: 7.8, label: 'Wed', dataPointText: '7.8%' },
    { value: 6.2, label: 'Thu', dataPointText: '6.2%' },
    { value: 5.5, label: 'Fri', dataPointText: '5.5%' },
    { value: 4.8, label: 'Sat', dataPointText: '4.8%' },
    { value: 3.5, label: 'Sun', dataPointText: '3.5%' },
  ];

  return (
    <Animated.View style={[styles.chartCard, animatedStyle]}>
      <View style={styles.chartHeader}>
        <View>
          <Text style={styles.chartMetricLabel}>Filler Words</Text>
          <View style={styles.chartValueRow}>
            <Text style={styles.chartCurrentValue}>3.5%</Text>
            <View style={styles.trendBadge}>
              <Text style={styles.trendText}>↘ -4.7%</Text>
            </View>
          </View>
        </View>
        <View style={styles.chartBestContainer}>
          <Text style={styles.chartBestLabel}>Best</Text>
          <Text style={styles.chartBestValue}>3.5%</Text>
        </View>
      </View>

      <LineChart
        data={mockData}
        width={SCREEN_WIDTH - (SPACING.lg * 4)}
        height={180}
        curved
        color={COLORS.primary}
        thickness={3}
        startFillColor={COLORS.primary}
        endFillColor={COLORS.primary}
        startOpacity={0.3}
        endOpacity={0.05}
        areaChart
        hideDataPoints={false}
        dataPointsColor={COLORS.primary}
        dataPointsRadius={4}
        spacing={(SCREEN_WIDTH - (SPACING.lg * 4)) / 8}
        initialSpacing={10}
        noOfSections={4}
        yAxisColor="transparent"
        xAxisColor={COLORS.border}
        yAxisTextStyle={styles.yAxisText}
        xAxisLabelTextStyle={styles.xAxisText}
        hideRules
        showVerticalLines={false}
        isAnimated
        animationDuration={750}
        pointerConfig={{
          pointerStripHeight: 160,
          pointerStripColor: COLORS.border,
          pointerStripWidth: 1,
          pointerColor: COLORS.primary,
          radius: 6,
          pointerLabelWidth: 80,
          pointerLabelHeight: 60,
          activatePointersOnLongPress: false,
          autoAdjustPointerLabelPosition: true,
          pointerLabelComponent: (items) => {
            return (
              <View style={styles.tooltipContainer}>
                <Text style={styles.tooltipLabel}>{items[0].label}</Text>
                <Text style={styles.tooltipValue}>{items[0].dataPointText}</Text>
              </View>
            );
          },
        }}
      />
    </Animated.View>
  );
}

// Animated feature item
function AnimatedFeatureItem({ icon, title, description, index }) {
  const translateY = useSharedValue(100);
  const opacity = useSharedValue(0);

  useEffect(() => {
    const delay = (index + 1) * staggerDelays.medium;

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
    <Animated.View style={[styles.featureItem, animatedStyle]}>
      <View style={styles.featureIconContainer}>
        <Ionicons name={icon} size={22} color={COLORS.primary} />
      </View>
      <View style={styles.featureContent}>
        <Text style={styles.featureTitle}>{title}</Text>
        <Text style={styles.featureDescription}>{description}</Text>
      </View>
    </Animated.View>
  );
}

export default function ProgressIntroScreen({ navigation }) {
  const features = [
    {
      icon: 'stats-chart-outline',
      title: 'Track All Metrics',
      description: 'Performance history for every metric'
    },
    {
      icon: 'trending-up-outline',
      title: 'See Improvement Trends',
      description: 'Visualize progress with charts'
    },
    {
      icon: 'trophy-outline',
      title: 'Compare to Your Best',
      description: 'Know and beat your records'
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
        <Text style={styles.header}>Track Your Progress</Text>
        <Text style={styles.subheader}>
          Watch yourself improve with detailed tracking and insights
        </Text>

        <AnimatedChartCard />

        <View style={styles.featuresContainer}>
          {features.map((feature, index) => (
            <AnimatedFeatureItem
              key={index}
              icon={feature.icon}
              title={feature.title}
              description={feature.description}
              index={index}
            />
          ))}
        </View>
      </ScrollView>

      <OnboardingNavigation
        currentStep={6}
        totalSteps={12}
        onContinue={() => navigation.navigate('Profile')}
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
  chartCard: {
    backgroundColor: COLORS.cardBackground,
    borderRadius: 16,
    borderWidth: 1,
    borderColor: COLORS.border,
    padding: SPACING.lg,
    marginBottom: SPACING.xl,
    shadowColor: COLORS.text,
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.08,
    shadowRadius: 8,
    elevation: 3,
  },
  chartHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: SPACING.md,
  },
  chartMetricLabel: {
    fontSize: 14,
    fontWeight: '600',
    color: COLORS.textSecondary,
    marginBottom: 4,
  },
  chartValueRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  chartCurrentValue: {
    fontSize: 28,
    fontWeight: 'bold',
    color: COLORS.text,
    marginRight: SPACING.sm,
  },
  trendBadge: {
    backgroundColor: COLORS.selectedBackground,
    paddingHorizontal: SPACING.xs,
    paddingVertical: 4,
    borderRadius: 6,
  },
  trendText: {
    fontSize: 12,
    fontWeight: '700',
    color: COLORS.success,
  },
  chartBestContainer: {
    alignItems: 'flex-end',
  },
  chartBestLabel: {
    fontSize: 12,
    fontWeight: '500',
    color: COLORS.textMuted,
    marginBottom: 2,
  },
  chartBestValue: {
    fontSize: 16,
    fontWeight: '700',
    color: COLORS.primary,
  },
  yAxisText: {
    fontSize: 11,
    color: COLORS.textMuted,
    fontWeight: '400',
  },
  xAxisText: {
    fontSize: 11,
    color: COLORS.textSecondary,
    fontWeight: '500',
  },
  tooltipContainer: {
    backgroundColor: COLORS.cardBackground,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: COLORS.border,
    padding: SPACING.xs,
    shadowColor: COLORS.text,
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  tooltipLabel: {
    fontSize: 11,
    fontWeight: '500',
    color: COLORS.textMuted,
    marginBottom: 2,
  },
  tooltipValue: {
    fontSize: 14,
    fontWeight: '700',
    color: COLORS.text,
  },
  featuresContainer: {
    marginTop: SPACING.md,
  },
  featureItem: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    marginBottom: SPACING.lg,
  },
  featureIconContainer: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: COLORS.selectedBackground,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: SPACING.md,
  },
  featureContent: {
    flex: 1,
  },
  featureTitle: {
    fontSize: 16,
    fontWeight: '700',
    color: COLORS.text,
    marginBottom: 4,
    lineHeight: 20,
  },
  featureDescription: {
    fontSize: 14,
    fontWeight: '400',
    color: COLORS.textSecondary,
    lineHeight: 20,
  },
});
