import React, { useState } from 'react';
import { View, Text, StyleSheet, ScrollView, TextInput, Alert } from 'react-native';
import Button from '../../components/Button';
import PricingCard from '../../components/PricingCard';
import AnimatedBackground from '../../components/AnimatedBackground';
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

    if (!paymentMethod || paymentMethod.length < 4) {
      Alert.alert(
        'Add Card Details',
        'Please enter your card number above to continue.',
        [
          {
            text: 'OK',
          },
        ]
      );
      return;
    }

    Alert.alert(
      'Payment Integration Coming Soon',
      'Payment processing will be integrated soon. For now, you can skip to explore the app.',
      [
        {
          text: 'OK',
          onPress: () => {
            // Navigate to the Practice screen
            navigation.navigate('Practice');
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
            // Navigate to the Practice screen
            navigation.navigate('Practice');
          },
        },
      ]
    );
  };

  return (
    <View style={styles.container}>
      <AnimatedBackground />
      <ScrollView
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}
      >
        <Text style={styles.header}>Choose Your Plan</Text>
        <Text style={styles.subheader}>
          Practice daily and stay 100% free forever
        </Text>

        {/* How It Works Card */}
        <View style={styles.howItWorksCard}>
          <Text style={styles.howItWorksTitle}>{HOW_IT_WORKS.title}</Text>
          {HOW_IT_WORKS.steps.map((step, index) => (
            <View key={index} style={styles.stepRow}>
              <Text style={styles.stepBullet}>•</Text>
              <Text style={styles.stepText}>{step}</Text>
            </View>
          ))}
        </View>

        {/* Pricing Plans */}
        <Text style={styles.sectionSubtitle}>
          Only charged if you miss a day
        </Text>

        {/* Side-by-side plan cards */}
        <View style={styles.plansContainer}>
          {PRICING_PLANS.map((plan) => (
            <View key={plan.id} style={styles.planWrapper}>
              <PricingCard
                title={plan.title}
                price={plan.price}
                period={plan.period}
                badge={plan.badge}
                savings={plan.savings}
                isSelected={selectedPlan === plan.id}
                onPress={() => handlePlanSelect(plan.id)}
                style={styles.planCard}
              />
            </View>
          ))}
        </View>

        {/* Benefits Section */}
        <View style={styles.benefitsSection}>
          <Text style={styles.benefitsTitle}>What's Included</Text>
          <View style={styles.benefitsList}>
            <View style={styles.benefitRow}>
              <Text style={styles.benefitIcon}>✓</Text>
              <Text style={styles.benefitText}>Unlimited speech analysis sessions</Text>
            </View>
            <View style={styles.benefitRow}>
              <Text style={styles.benefitIcon}>✓</Text>
              <Text style={styles.benefitText}>Advanced coaching insights</Text>
            </View>
            <View style={styles.benefitRow}>
              <Text style={styles.benefitIcon}>✓</Text>
              <Text style={styles.benefitText}>Progress tracking and analytics</Text>
            </View>
            <View style={styles.benefitRow}>
              <Text style={styles.benefitIcon}>✓</Text>
              <Text style={styles.benefitText}>Dedicated support</Text>
            </View>
          </View>
        </View>

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
            Secure payment processing
          </Text>
        </View>

        {/* Fine Print */}
        <Text style={styles.finePrint}>
          Cancel anytime. No charges if you practice daily.
        </Text>
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
    paddingBottom: 240, // Extra space for two buttons and gradient
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
    fontSize: 16,
    fontWeight: '500',
    color: COLORS.textSecondary,
    textAlign: 'center',
    marginBottom: SPACING.xl,
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
  sectionSubtitle: {
    fontSize: 14,
    fontWeight: '600',
    color: COLORS.textSecondary,
    marginBottom: SPACING.md,
    textAlign: 'center',
  },
  plansContainer: {
    flexDirection: 'row',
    gap: SPACING.md,
    marginBottom: SPACING.xl,
  },
  planWrapper: {
    flex: 1,
  },
  planCard: {
    marginBottom: 0,
  },
  benefitsSection: {
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
    shadowOpacity: 0.05,
    shadowRadius: 4,
    elevation: 2,
  },
  benefitsTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: COLORS.text,
    marginBottom: SPACING.md,
    textAlign: 'center',
  },
  benefitsList: {
    gap: SPACING.sm,
  },
  benefitRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
  },
  benefitIcon: {
    fontSize: 18,
    fontWeight: 'bold',
    color: COLORS.primary,
    marginRight: SPACING.sm,
    width: 24,
  },
  benefitText: {
    fontSize: 15,
    fontWeight: '500',
    color: COLORS.text,
    flex: 1,
    lineHeight: 22,
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
  buttonContainer: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    padding: SPACING.lg,
    pointerEvents: 'box-none',
  },
  button: {
    width: '100%',
  },
  skipButton: {
    marginTop: SPACING.sm,
  },
});
