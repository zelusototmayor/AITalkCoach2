import React from 'react';
import { View, Text, StyleSheet, ScrollView } from 'react-native';
import Button from '../../components/Button';
import InfoCard from '../../components/InfoCard';
import { COLORS, SPACING } from '../../constants/colors';
import { MOTIVATION_TIPS, GENERIC_STAT } from '../../constants/onboardingData';
import { useOnboarding } from '../../context/OnboardingContext';

export default function MotivationScreen({ navigation }) {
  const { onboardingData } = useOnboarding();

  // Get tip based on first selected goal, or use default
  const firstGoalId = onboardingData.goals[0];
  const motivationTip = MOTIVATION_TIPS[firstGoalId] || MOTIVATION_TIPS.default;

  return (
    <View style={styles.container}>
      <ScrollView
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}
      >
        <Text style={styles.header}>You're Not Alone</Text>

        <InfoCard
          icon="💪"
          content={motivationTip}
          style={styles.tipCard}
        />

        <InfoCard
          icon={GENERIC_STAT.icon}
          content={GENERIC_STAT.title}
          style={styles.statCard}
        />

        {/* Pagination dots */}
        <View style={styles.paginationContainer}>
          {[...Array(9)].map((_, index) => (
            <View
              key={index}
              style={[
                styles.dot,
                index === 3 && styles.activeDot, // Screen 4 is active (index 3)
              ]}
            />
          ))}
        </View>
      </ScrollView>

      <View style={styles.buttonContainer}>
        <Button
          title="Continue →"
          onPress={() => navigation.navigate('Profile')}
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
    marginBottom: SPACING.xxl,
    lineHeight: 36,
  },
  tipCard: {
    minHeight: 140,
    marginBottom: SPACING.lg,
  },
  statCard: {
    minHeight: 100,
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
