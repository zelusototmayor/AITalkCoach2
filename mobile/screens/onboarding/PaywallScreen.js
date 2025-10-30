import React, { useState } from 'react';
import { View, Text, StyleSheet, ScrollView, TextInput, Alert } from 'react-native';
import Button from '../../components/Button';
import PricingCard from '../../components/PricingCard';
import { COLORS, SPACING } from '../../constants/colors';
import { PRICING_PLANS, HOW_IT_WORKS } from '../../constants/onboardingData';
import { useOnboarding } from '../../context/OnboardingContext';

export default function PaywallScreen({ navigation }) {
  const { updateOnboardingData } = useOnboarding();
  const [selectedPlan, setSelectedPlan] = useState('yearly'); // Default to yearly
  const [paymentMethod, setPaymentMethod] = useState('');

  const handlePlanSelect = (planId) => {
    setSelectedPlan(planId);
  };

  const handleAddPayment = () => {
    // For now, just show a placeholder message
    // Later: Integrate with Stripe/RevenueCat
    updateOnboardingData({
      selectedPlan,
    });

    Alert.alert(
      'Payment Setup',
      'Payment integration coming soon! For now, you can skip to explore the app.',
      [
        {
          text: 'OK',
          onPress: () => {
            // TODO: Navigate to main app when ready
            console.log('Would navigate to main app');
          },
        },
      ]
    );
  };

  const handleSkip = () => {
    Alert.alert(
      'Skip Payment',
      'You can always add a payment method later in settings.',
      [
        {
          text: 'Cancel',
          style: 'cancel',
        },
        {
          text: 'Skip',
          onPress: () => {
            // TODO: Navigate to main app when ready
            console.log('Would navigate to main app (skipped payment)');
          },
        },
      ]
    );
  };

  return (
    <View style={styles.container}>
      <ScrollView
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}
      >
        <Text style={styles.header}>Practice daily, use free forever</Text>

        {/* How It Works Card */}
        <View style={styles.howItWorksCard}>
          <Text style={styles.howItWorksIcon}>{HOW_IT_WORKS.icon}</Text>
          <Text style={styles.howItWorksTitle}>{HOW_IT_WORKS.title}</Text>
          {HOW_IT_WORKS.steps.map((step, index) => (
            <View key={index} style={styles.stepRow}>
              <Text style={styles.stepBullet}>•</Text>
              <Text style={styles.stepText}>{step}</Text>
            </View>
          ))}
        </View>

        {/* Pricing Plans */}
        <Text style={styles.sectionTitle}>Choose Your Plan</Text>
        <Text style={styles.sectionSubtitle}>
          Only charged if you miss a day
        </Text>

        {PRICING_PLANS.map((plan) => (
          <PricingCard
            key={plan.id}
            title={plan.title}
            price={plan.price}
            period={plan.period}
            badge={plan.badge}
            savings={plan.savings}
            isSelected={selectedPlan === plan.id}
            onPress={() => handlePlanSelect(plan.id)}
          />
        ))}

        {/* Payment Method Input (Placeholder) */}
        <View style={styles.paymentSection}>
          <Text style={styles.paymentLabel}>Payment Method</Text>
          <TextInput
            style={styles.paymentInput}
            placeholder="Card number"
            placeholderTextColor={COLORS.textMuted}
            value={paymentMethod}
            onChangeText={setPaymentMethod}
            keyboardType="numeric"
            maxLength={19}
          />
          <Text style={styles.paymentNote}>
            💳 Secure payment processing
          </Text>
        </View>

        {/* Fine Print */}
        <Text style={styles.finePrint}>
          Cancel anytime. No charges if you practice daily.
        </Text>

        {/* Pagination dots */}
        <View style={styles.paginationContainer}>
          {[...Array(9)].map((_, index) => (
            <View
              key={index}
              style={[
                styles.dot,
                index === 8 && styles.activeDot, // Screen 9 is active (index 8)
              ]}
            />
          ))}
        </View>
      </ScrollView>

      <View style={styles.buttonContainer}>
        <Button
          title="Add Payment and Start"
          onPress={handleAddPayment}
          variant="primary"
          style={styles.button}
        />
        <Button
          title="Skip for now"
          onPress={handleSkip}
          variant="secondary"
          style={[styles.button, styles.skipButton]}
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
    paddingBottom: 200, // Extra space for two buttons
  },
  header: {
    fontSize: 28,
    fontWeight: 'bold',
    color: COLORS.text,
    textAlign: 'center',
    marginBottom: SPACING.xxl,
    lineHeight: 36,
  },
  howItWorksCard: {
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
    shadowOpacity: 0.05,
    shadowRadius: 4,
    elevation: 2,
  },
  howItWorksIcon: {
    fontSize: 40,
    textAlign: 'center',
    marginBottom: SPACING.sm,
  },
  howItWorksTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: COLORS.text,
    textAlign: 'center',
    marginBottom: SPACING.md,
  },
  stepRow: {
    flexDirection: 'row',
    marginBottom: SPACING.sm,
    paddingLeft: SPACING.sm,
  },
  stepBullet: {
    fontSize: 18,
    fontWeight: 'bold',
    color: COLORS.primary,
    marginRight: SPACING.sm,
  },
  stepText: {
    fontSize: 15,
    fontWeight: '500',
    color: COLORS.text,
    flex: 1,
    lineHeight: 22,
  },
  sectionTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    color: COLORS.text,
    marginBottom: SPACING.xs,
    textAlign: 'center',
  },
  sectionSubtitle: {
    fontSize: 14,
    fontWeight: '600',
    color: COLORS.textSecondary,
    marginBottom: SPACING.lg,
    textAlign: 'center',
  },
  paymentSection: {
    marginTop: SPACING.lg,
    marginBottom: SPACING.lg,
  },
  paymentLabel: {
    fontSize: 16,
    fontWeight: '600',
    color: COLORS.text,
    marginBottom: SPACING.sm,
  },
  paymentInput: {
    backgroundColor: COLORS.cardBackground,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: COLORS.border,
    paddingVertical: SPACING.md,
    paddingHorizontal: SPACING.lg,
    fontSize: 16,
    fontWeight: '500',
    color: COLORS.text,
    marginBottom: SPACING.sm,
  },
  paymentNote: {
    fontSize: 14,
    fontWeight: '500',
    color: COLORS.textSecondary,
    textAlign: 'center',
  },
  finePrint: {
    fontSize: 12,
    fontWeight: '400',
    color: COLORS.textMuted,
    textAlign: 'center',
    marginTop: SPACING.lg,
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
  skipButton: {
    marginTop: SPACING.sm,
  },
});
