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
import { MOTIVATION_TIPS, MOTIVATION_STATS } from '../../constants/onboardingData';
import { useOnboarding } from '../../context/OnboardingContext';
import { springConfigs, staggerDelays, animationValues } from '../../utils/animationConfigs';

// Animated card component with stacking effect (slide up + scale)
function AnimatedMotivationCard({ icon, title, description, index }) {
  const translateY = useSharedValue(100);
  const opacity = useSharedValue(0);
  const scale = useSharedValue(animationValues.scaleStart);

  useEffect(() => {
    // Quick stagger (60ms) for fast "stacking" feel
    const delay = index * staggerDelays.quick;

    translateY.value = withDelay(
      delay,
      withSpring(0, springConfigs.gentle)
    );

    opacity.value = withDelay(
      delay,
      withSpring(1, springConfigs.gentle)
    );

    scale.value = withDelay(
      delay,
      withSpring(animationValues.scaleEnd, springConfigs.gentle)
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
    <Animated.View style={[styles.card, animatedStyle]}>
      <Image source={icon} style={styles.cardIcon} resizeMode="contain" />
      <Text style={styles.cardTitle}>{title}</Text>
      <Text style={styles.cardDescription}>{description}</Text>
    </Animated.View>
  );
}

export default function MotivationScreen({ navigation }) {
  const { onboardingData } = useOnboarding();

  // Get tip based on first selected goal, or use default
  const firstGoalId = onboardingData.goals?.[0];
  const motivationTip = MOTIVATION_TIPS[firstGoalId] || MOTIVATION_TIPS.default;

  return (
    <View style={styles.container}>
      <AnimatedBackground />
      <QuitOnboardingButton />
      <ScrollView
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}
      >
        <Text style={styles.header}>You're Not Alone</Text>

        {/* Primary motivation card based on goal */}
        <AnimatedMotivationCard
          icon={require('../../assets/icons/strong.png')}
          title={motivationTip.title}
          description={motivationTip.description}
          index={0}
        />

        {/* Additional motivation stats */}
        {MOTIVATION_STATS.map((stat, index) => (
          <AnimatedMotivationCard
            key={index}
            icon={stat.icon}
            title={stat.title}
            description={stat.description}
            index={index + 1}
          />
        ))}
      </ScrollView>

      <OnboardingNavigation
        currentStep={2}
        totalSteps={8}
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
    marginBottom: SPACING.lg,
    lineHeight: 36,
  },
  card: {
    backgroundColor: COLORS.cardBackground,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: COLORS.border,
    padding: SPACING.lg,
    marginBottom: SPACING.md,
    alignItems: 'center',
    shadowColor: COLORS.text,
    shadowOffset: {
      width: 0,
      height: 1,
    },
    shadowOpacity: 0.05,
    shadowRadius: 3,
    elevation: 2,
  },
  cardIcon: {
    width: 56,
    height: 56,
    marginBottom: SPACING.sm,
  },
  cardTitle: {
    fontSize: 17,
    fontWeight: '700',
    color: COLORS.text,
    textAlign: 'center',
    marginBottom: SPACING.xs,
    lineHeight: 22,
  },
  cardDescription: {
    fontSize: 14,
    fontWeight: '400',
    color: COLORS.text,
    textAlign: 'center',
    lineHeight: 20,
  },
});
