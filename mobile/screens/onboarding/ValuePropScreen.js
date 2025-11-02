import React from 'react';
import { View, Text, StyleSheet, ScrollView } from 'react-native';
import OnboardingNavigation from '../../components/OnboardingNavigation';
import AnimatedBackground from '../../components/AnimatedBackground';
import QuitOnboardingButton from '../../components/QuitOnboardingButton';
import { COLORS, SPACING, TYPOGRAPHY } from '../../constants/colors';
import { VALUE_PROPS } from '../../constants/onboardingData';

export default function ValuePropScreen({ navigation }) {
  return (
    <View style={styles.container}>
      <AnimatedBackground />
      <QuitOnboardingButton />
      <ScrollView
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}
      >
        <Text style={styles.header}>
          Master the #1 skill that opens every door
        </Text>

        <Text style={styles.subheader}>
          According to LinkedIn, communication is the most in-demand skill across industries.
        </Text>

        <View style={styles.cardsContainer}>
          {VALUE_PROPS.map((prop) => (
            <View key={prop.id} style={styles.card}>
              <Text style={styles.cardIcon}>{prop.icon}</Text>
              <Text style={styles.cardTitle}>{prop.title}</Text>
              <Text style={styles.cardDescription}>{prop.description}</Text>
              <Text style={styles.cardSource}>{prop.source}</Text>
            </View>
          ))}
        </View>
      </ScrollView>

      <OnboardingNavigation
        currentStep={0}
        totalSteps={8}
        onContinue={() => navigation.navigate('Goals')}
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
    marginBottom: SPACING.md,
    lineHeight: 36,
  },
  subheader: {
    fontSize: 15,
    color: COLORS.textSecondary,
    textAlign: 'center',
    marginBottom: SPACING.xl,
    paddingHorizontal: SPACING.md,
    lineHeight: 22,
  },
  cardsContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
  },
  card: {
    width: '48%',
    backgroundColor: COLORS.cardBackground,
    borderRadius: 16,
    borderWidth: 1,
    borderColor: COLORS.border,
    padding: SPACING.lg,
    alignItems: 'center',
    justifyContent: 'flex-start',
    minHeight: 180,
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
  cardIcon: {
    fontSize: 36,
    marginBottom: SPACING.sm,
  },
  cardTitle: {
    fontSize: 17,
    fontWeight: '700',
    color: COLORS.text,
    textAlign: 'center',
    lineHeight: 22,
    marginBottom: SPACING.xs,
  },
  cardDescription: {
    fontSize: 13,
    fontWeight: '400',
    color: COLORS.text,
    textAlign: 'center',
    lineHeight: 18,
    marginBottom: SPACING.sm,
  },
  cardSource: {
    fontSize: 11,
    fontWeight: '500',
    color: COLORS.textSecondary,
    textAlign: 'center',
    fontStyle: 'italic',
    marginTop: 'auto',
  },
});
