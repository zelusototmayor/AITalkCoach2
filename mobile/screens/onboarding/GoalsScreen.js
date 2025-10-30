import React, { useState } from 'react';
import { View, Text, StyleSheet, ScrollView } from 'react-native';
import Button from '../../components/Button';
import GoalCard from '../../components/GoalCard';
import { COLORS, SPACING } from '../../constants/colors';
import { SPEAKING_GOALS } from '../../constants/onboardingData';
import { useOnboarding } from '../../context/OnboardingContext';

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
      <ScrollView
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}
      >
        <Text style={styles.header}>What are your speaking goals?</Text>

        <View style={styles.cardsContainer}>
          {SPEAKING_GOALS.map((goal) => (
            <GoalCard
              key={goal.id}
              goal={goal}
              isSelected={isSelected(goal.id)}
              onPress={() => toggleGoal(goal.id)}
            />
          ))}
        </View>

        {/* Pagination dots */}
        <View style={styles.paginationContainer}>
          {[...Array(9)].map((_, index) => (
            <View
              key={index}
              style={[
                styles.dot,
                index === 2 && styles.activeDot, // Screen 3 is active (index 2)
              ]}
            />
          ))}
        </View>
      </ScrollView>

      <View style={styles.buttonContainer}>
        <Button
          title="Continue →"
          onPress={handleContinue}
          variant="primary"
          disabled={selectedGoals.length === 0}
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
    marginBottom: SPACING.xxl,
    lineHeight: 36,
  },
  cardsContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
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
    width: 10,
    height: 10,
    borderRadius: 5,
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
});
