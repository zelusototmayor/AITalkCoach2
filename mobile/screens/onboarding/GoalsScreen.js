import React, { useState, useEffect } from 'react';
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
import GoalCard from '../../components/GoalCard';
import { COLORS, SPACING } from '../../constants/colors';
import { SPEAKING_GOALS } from '../../constants/onboardingData';
import { useOnboarding } from '../../context/OnboardingContext';
import { springConfigs, staggerDelays, entrancePresets } from '../../utils/animationConfigs';

// Animated wrapper for GoalCard with waterfall effect
function AnimatedGoalCard({ goal, index, isSelected, onPress }) {
  const translateY = useSharedValue(entrancePresets.fadeSlideUp.initialTranslateY);
  const opacity = useSharedValue(0);

  useEffect(() => {
    // Stagger each card by 80ms for waterfall effect
    const delay = index * staggerDelays.medium;

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
    <Animated.View style={[styles.cardWrapper, animatedStyle]}>
      <GoalCard goal={goal} isSelected={isSelected} onPress={onPress} />
    </Animated.View>
  );
}

export default function GoalsScreen({ navigation }) {
  const { onboardingData, updateOnboardingData } = useOnboarding();
  const [selectedGoals, setSelectedGoals] = useState(onboardingData.goals || []);

  const toggleGoal = (goalId) => {
    setSelectedGoals((prev) => {
      if (prev.includes(goalId)) {
        return prev.filter((id) => id !== goalId);
      } else {
        return [...prev, goalId];
      }
    });
  };

  const isSelected = (goalId) => selectedGoals.includes(goalId);

  const handleContinue = () => {
    // Store selected goals in context
    updateOnboardingData({ goals: selectedGoals });
    // Navigate to Motivation screen
    navigation.navigate('Motivation');
  };

  return (
    <View style={styles.container}>
      <AnimatedBackground />
      <QuitOnboardingButton />
      <ScrollView
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}
      >
        <Text style={styles.header}>What are your speaking goals?</Text>
        <Text style={styles.subheader}>Select all that apply</Text>

        <View style={styles.cardsContainer}>
          {SPEAKING_GOALS.map((goal, index) => (
            <AnimatedGoalCard
              key={goal.id}
              goal={goal}
              index={index}
              isSelected={isSelected(goal.id)}
              onPress={() => toggleGoal(goal.id)}
            />
          ))}
        </View>
      </ScrollView>

      <OnboardingNavigation
        currentStep={1}
        totalSteps={8}
        onContinue={handleContinue}
        continueDisabled={selectedGoals.length === 0}
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
    marginBottom: SPACING.sm,
    lineHeight: 36,
  },
  subheader: {
    fontSize: 15,
    color: COLORS.textSecondary,
    textAlign: 'center',
    marginBottom: SPACING.xl,
  },
  cardsContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
  },
  cardWrapper: {
    width: '48%',
  },
});
