import React from 'react';
import { View, Text, StyleSheet, ScrollView } from 'react-native';
import OnboardingNavigation from '../../components/OnboardingNavigation';
import { COLORS, SPACING } from '../../constants/colors';
import { MOTIVATION_TIPS, MOTIVATION_STATS } from '../../constants/onboardingData';
import { useOnboarding } from '../../context/OnboardingContext';

export default function MotivationScreen({ navigation }) {
  const { onboardingData } = useOnboarding();

  // Get tip based on first selected goal, or use default
  const firstGoalId = onboardingData.goals?.[0];
  const motivationTip = MOTIVATION_TIPS[firstGoalId] || MOTIVATION_TIPS.default;

  return (
    <View style={styles.container}>
      <ScrollView
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}
      >
        <Text style={styles.header}>You're Not Alone</Text>

        {/* Primary motivation card based on goal */}
        <View style={styles.card}>
          <Text style={styles.cardIcon}>💪</Text>
          <Text style={styles.cardTitle}>{motivationTip.title}</Text>
          <Text style={styles.cardDescription}>{motivationTip.description}</Text>
        </View>

        {/* Additional motivation stats */}
        {MOTIVATION_STATS.map((stat, index) => (
          <View key={index} style={styles.card}>
            <Text style={styles.cardIcon}>{stat.icon}</Text>
            <Text style={styles.cardTitle}>{stat.title}</Text>
            <Text style={styles.cardDescription}>{stat.description}</Text>
          </View>
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
    paddingBottom: 120,
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
    fontSize: 36,
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
