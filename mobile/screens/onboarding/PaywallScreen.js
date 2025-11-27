import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, ScrollView, Alert, ActivityIndicator, Linking } from 'react-native';
import Button from '../../components/Button';
import PricingCard from '../../components/PricingCard';
import FeatureHighlightCard from '../../components/FeatureHighlightCard';
import AnimatedBackground from '../../components/AnimatedBackground';
import QuitOnboardingButton from '../../components/QuitOnboardingButton';
import { COLORS, SPACING } from '../../constants/colors';
import { PRICING_PLANS, HOW_IT_WORKS } from '../../constants/onboardingData';
import { useOnboarding } from '../../context/OnboardingContext';
import { useAuth } from '../../context/AuthContext';
import { SHOW_FREE_FOREVER } from '../../config/features';
import * as subscriptionService from '../../services/subscriptionService';
import analytics from '../../services/analytics';

export default function PaywallScreen({ navigation }) {
  const { updateOnboardingData, onboardingData } = useOnboarding();
  const { completeOnboarding, user } = useAuth();
  const [selectedPlan, setSelectedPlan] = useState('yearly'); // Default to yearly
  const [offerings, setOfferings] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isPurchasing, setIsPurchasing] = useState(false);
  const [loadError, setLoadError] = useState(null);
  const [retryCount, setRetryCount] = useState(0);

  // Load offerings from RevenueCat
  useEffect(() => {
    loadOfferings();

    // Track paywall viewed
    analytics.track('Paywall Viewed', {
      source: 'onboarding',
      plan_count: PRICING_PLANS.length,
      free_forever_mode: SHOW_FREE_FOREVER,
    });
  }, []);

  const loadOfferings = async (isRetry = false) => {
    try {
      setIsLoading(true);
      setLoadError(null);

      // Initialize RevenueCat with user ID or anonymous ID
      // During onboarding, user is logged in, so we have user.id
      // But if this screen is accessed before login, use anonymous ID
      const userId = user && user.id ? user.id.toString() : `anonymous_${Date.now()}`;
      console.log('🚀 PaywallScreen: Initializing RevenueCat with userId:', userId);

      const initResult = await subscriptionService.initializePurchases(userId);
      console.log('🚀 PaywallScreen: RevenueCat initialization result:', initResult);

      if (!initResult) {
        throw new Error('Failed to initialize RevenueCat SDK');
      }

      console.log('🚀 PaywallScreen: Fetching offerings...');

      // Validate configuration in development
      if (__DEV__) {
        const diagnostics = await subscriptionService.validateRevenueCatConfig();
        console.log('📊 RevenueCat diagnostics:', diagnostics);
      }

      const availableOfferings = await subscriptionService.getOfferings();
      console.log('🚀 PaywallScreen: Received offerings:', availableOfferings.length, 'packages');

      setOfferings(availableOfferings);

      if (availableOfferings.length === 0) {
        console.warn('⚠️ PaywallScreen: No offerings received. Check RevenueCat dashboard.');

        // Auto-retry once after a delay for network issues
        if (!isRetry && retryCount === 0) {
          console.log('🔄 Auto-retrying in 2 seconds...');
          setTimeout(() => {
            setRetryCount(1);
            loadOfferings(true);
          }, 2000);
          return;
        }

        // Set error state if auto-retry also failed
        setLoadError('no_offerings');
      }
    } catch (error) {
      console.error('❌ PaywallScreen: Error loading offerings:', error);
      console.error('Error details:', {
        message: error.message,
        code: error.code,
        stack: error.stack,
      });

      // Auto-retry once after a delay for network issues
      if (!isRetry && retryCount === 0) {
        console.log('🔄 Auto-retrying after error in 2 seconds...');
        setTimeout(() => {
          setRetryCount(1);
          loadOfferings(true);
        }, 2000);
        return;
      }

      // Set error state for graceful handling
      setLoadError('network_error');
    } finally {
      setIsLoading(false);
    }
  };

  const handleRetry = () => {
    setRetryCount(prev => prev + 1);
    loadOfferings(true);
  };

  const handlePlanSelect = (planId) => {
    setSelectedPlan(planId);

    // Track plan selection
    analytics.track('Plan Selected', {
      plan_id: planId,
      source: 'onboarding',
    });
  };

  const handleStartTrial = async () => {
    if (isPurchasing) return;

    try {
      setIsPurchasing(true);

      // Find the selected package
      const selectedPackage = offerings.find(
        offering => offering.productId === (selectedPlan === 'monthly' ? '04' : '05')
      );

      if (!selectedPackage) {
        Alert.alert('Error', 'Selected plan not available. Please try again.');
        return;
      }

      // Track purchase started
      analytics.track('Purchase Started', {
        plan_id: selectedPlan,
        product_id: selectedPackage.productId,
        source: 'onboarding',
      });

      // Purchase the package via RevenueCat
      // Use the original RevenueCat package object (rcPackage)
      const result = await subscriptionService.purchasePackage(selectedPackage.rcPackage);

      if (result.success) {
        // Track purchase success
        analytics.track('Purchase Completed', {
          plan_id: selectedPlan,
          product_id: selectedPackage.productId,
          source: 'onboarding',
        });

        // Purchase successful
        updateOnboardingData({
          selectedPlan,
          hasActiveSubscription: true,
        });

        // Complete onboarding with demographics data
        const onboardingResult = await completeOnboarding(onboardingData);
        if (onboardingResult.success) {
          // MainNavigator will automatically switch to AppStack
          console.log('Subscription activated and onboarding completed');
        } else {
          Alert.alert('Error', 'Failed to complete onboarding. Please try again.');
        }
      } else if (result.cancelled) {
        // Track purchase cancellation
        analytics.track('Purchase Cancelled', {
          plan_id: selectedPlan,
          product_id: selectedPackage.productId,
          source: 'onboarding',
        });

        // User cancelled, do nothing
        console.log('User cancelled purchase');
      } else {
        // Track purchase failure
        analytics.track('Purchase Failed', {
          plan_id: selectedPlan,
          product_id: selectedPackage.productId,
          source: 'onboarding',
          error_message: result.error || 'Unknown error',
          is_recoverable: result.isRecoverable,
        });

        // Error occurred - show appropriate message with retry option
        const errorTitle = result.isRecoverable ? 'Purchase Temporarily Failed' : 'Purchase Failed';
        const errorMessage = result.error || 'Please try again.';

        // Show technical details in development
        if (__DEV__ && result.technicalDetails) {
          console.log('Technical error details:', result.technicalDetails);
        }

        // Show alert with retry option for recoverable errors
        if (result.isRecoverable) {
          Alert.alert(
            errorTitle,
            `${errorMessage}\n\nThis is a temporary issue. Would you like to try again?`,
            [
              { text: 'Cancel', style: 'cancel' },
              {
                text: 'Try Again',
                onPress: () => {
                  // Retry after a short delay
                  setTimeout(() => handleStartTrial(), 500);
                }
              },
            ]
          );
        } else {
          Alert.alert(
            errorTitle,
            errorMessage,
            [
              { text: 'OK', style: 'default' },
              {
                text: 'Restore Purchases',
                onPress: handleRestore,
                style: 'default'
              },
            ]
          );
        }
      }
    } catch (error) {
      console.error('Error during purchase:', error);
      Alert.alert(
        'Unexpected Error',
        'Failed to process purchase. Please restart the app and try again.',
        [
          { text: 'OK', style: 'default' },
        ]
      );
    } finally {
      setIsPurchasing(false);
    }
  };

  const handleRestore = async () => {
    try {
      setIsLoading(true);

      // Track restore purchases clicked
      analytics.track('Restore Purchases Clicked', {
        source: 'onboarding',
      });

      const result = await subscriptionService.restorePurchases();

      if (result.success && result.hasActiveSubscription) {
        // Track restore success
        analytics.track('Restore Purchases Succeeded', {
          source: 'onboarding',
        });

        Alert.alert(
          'Success',
          'Your subscription has been restored!',
          [
            {
              text: 'OK',
              onPress: async () => {
                const onboardingResult = await completeOnboarding(onboardingData);
                if (!onboardingResult.success) {
                  Alert.alert('Error', 'Failed to complete onboarding. Please try again.');
                }
              },
            },
          ]
        );
      } else {
        // Track restore failure (no subscription found)
        analytics.track('Restore Purchases Failed', {
          source: 'onboarding',
          error_message: 'No active subscription found',
        });

        Alert.alert('No Subscription Found', 'No active subscription found to restore.');
      }
    } catch (error) {
      console.error('Error restoring purchases:', error);

      // Track restore error
      analytics.track('Restore Purchases Failed', {
        source: 'onboarding',
        error_message: error.message || 'Unknown error',
      });

      Alert.alert('Error', 'Failed to restore purchases. Please try again.');
    } finally {
      setIsLoading(false);
    }
  };

  // Show loading state
  if (isLoading) {
    return (
      <View style={styles.container}>
        <AnimatedBackground />
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="large" color={COLORS.primary} />
          <Text style={styles.loadingText}>
            {retryCount > 0 ? 'Retrying...' : 'Loading subscription options...'}
          </Text>
        </View>
      </View>
    );
  }

  // Show error state with retry option
  if (loadError) {
    return (
      <View style={styles.container}>
        <AnimatedBackground />
        <QuitOnboardingButton />
        <View style={styles.errorContainer}>
          <Text style={styles.errorIcon}>⚠️</Text>
          <Text style={styles.errorTitle}>
            {loadError === 'no_offerings'
              ? 'Subscription Plans Unavailable'
              : 'Connection Issue'}
          </Text>
          <Text style={styles.errorMessage}>
            {loadError === 'no_offerings'
              ? 'We\'re having trouble loading subscription plans. This may be temporary.'
              : 'Unable to connect to the subscription service. Please check your internet connection.'}
          </Text>
          <Button
            title="Try Again"
            onPress={handleRetry}
            variant="primary"
            style={styles.retryButton}
          />
          <Text style={styles.errorHint}>
            If the problem persists, please try again later or contact support.
          </Text>
        </View>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <AnimatedBackground />
      <QuitOnboardingButton />
      <ScrollView
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}
      >
        {/* Hero Section */}
        <View style={styles.heroSection}>
          <Text style={styles.heroText}>
            Speak with{'\n'}
            <Text style={styles.heroHighlight}>Unstoppable Confidence</Text>
          </Text>
          <Text style={styles.heroSubtext}>
            Join top 1% of communicators practicing daily.
          </Text>
        </View>

        {/* Review Card */}
        <View style={styles.reviewCard}>
          <View style={styles.starsRow}>
            <Text style={styles.starIcon}>⭐</Text>
            <Text style={styles.starIcon}>⭐</Text>
            <Text style={styles.starIcon}>⭐</Text>
            <Text style={styles.starIcon}>⭐</Text>
            <Text style={styles.starIcon}>⭐</Text>
          </View>
          <Text style={styles.reviewText}>
            "The real-time feedback is invaluable! I love the specific recommendations on speed, fluency, and fillers. This is a definite game-changer!"
          </Text>
          <Text style={styles.reviewAuthor}>— Cassandra Thomas, Pro90d Speech Course</Text>
        </View>

        {/* Pricing Plans */}
        <View style={styles.plansContainer}>
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
              style={styles.planCard}
              bestValue={plan.id === 'yearly'}
            />
          ))}
        </View>

        {/* Benefits Section */}
        <View style={styles.benefitsSection}>
          <View style={styles.benefitRow}>
            <View style={styles.checkmarkCircle}>
              <Text style={styles.checkmark}>✓</Text>
            </View>
            <Text style={styles.benefitText}>Unlimited AI Speech Analysis</Text>
          </View>
          <View style={styles.benefitRow}>
            <View style={styles.checkmarkCircle}>
              <Text style={styles.checkmark}>✓</Text>
            </View>
            <Text style={styles.benefitText}>Personalized Coaching Plan</Text>
          </View>
          <View style={styles.benefitRow}>
            <View style={styles.checkmarkCircle}>
              <Text style={styles.checkmark}>✓</Text>
            </View>
            <Text style={styles.benefitText}>Progress Tracking & Analytics</Text>
          </View>
          <View style={styles.benefitRow}>
            <View style={styles.checkmarkCircle}>
              <Text style={styles.checkmark}>✓</Text>
            </View>
            <Text style={styles.benefitText}>Daily Practice Drills</Text>
          </View>
        </View>

        {/* Fine Print */}
        <Text style={styles.finePrint}>
          {SHOW_FREE_FOREVER
            ? "Cancel anytime. No charges if you practice daily."
            : "Cancel anytime during your trial. Subscription auto-renews after 3 days."}
        </Text>

        {/* Terms and Privacy Policy Links */}
        <Text style={styles.finePrint}>
          By subscribing, you agree to our{' '}
          <Text
            style={styles.linkText}
            onPress={() => Linking.openURL('https://aitalkcoach.com/terms')}
          >
            Terms of Use
          </Text>
          {' '}and{' '}
          <Text
            style={styles.linkText}
            onPress={() => Linking.openURL('https://aitalkcoach.com/privacy')}
          >
            Privacy Policy
          </Text>
          .
        </Text>

        {/* Restore Purchases Link */}
        <Text style={styles.restoreText} onPress={handleRestore}>
          Already subscribed? Restore purchases
        </Text>
      </ScrollView>

      <View style={styles.buttonContainer}>
        <Button
          title={isPurchasing ? "Processing..." : "Start 3-Day Free Trial"}
          onPress={handleStartTrial}
          variant="primary"
          style={styles.button}
          disabled={isPurchasing}
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
    paddingBottom: 240,
  },
  heroSection: {
    marginBottom: SPACING.xl,
    paddingTop: SPACING.md,
  },
  heroText: {
    fontSize: 36,
    fontWeight: 'bold',
    color: COLORS.text,
    textAlign: 'center',
    marginBottom: SPACING.sm,
    lineHeight: 42,
  },
  heroHighlight: {
    color: COLORS.primary,
  },
  heroSubtext: {
    fontSize: 15,
    fontWeight: '400',
    color: COLORS.textSecondary,
    textAlign: 'center',
    lineHeight: 22,
  },
  reviewCard: {
    backgroundColor: COLORS.cardBackground,
    borderRadius: 16,
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
  starsRow: {
    flexDirection: 'row',
    marginBottom: SPACING.sm,
    gap: 4,
  },
  starIcon: {
    fontSize: 18,
  },
  reviewText: {
    fontSize: 15,
    fontWeight: '400',
    color: COLORS.text,
    lineHeight: 22,
    marginBottom: SPACING.sm,
    fontStyle: 'italic',
  },
  reviewAuthor: {
    fontSize: 14,
    fontWeight: '600',
    color: COLORS.textSecondary,
  },
  benefitsSection: {
    marginBottom: SPACING.xl,
  },
  benefitRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: SPACING.md,
  },
  checkmarkCircle: {
    width: 28,
    height: 28,
    borderRadius: 14,
    backgroundColor: COLORS.success,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: SPACING.md,
  },
  checkmark: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#FFFFFF',
  },
  benefitText: {
    fontSize: 17,
    fontWeight: '400',
    color: COLORS.text,
    flex: 1,
  },
  plansContainer: {
    marginBottom: SPACING.xl,
  },
  planCard: {
    marginBottom: SPACING.md,
  },
  finePrint: {
    fontSize: 12,
    fontWeight: '400',
    color: COLORS.textMuted,
    textAlign: 'center',
    marginTop: SPACING.lg,
    marginBottom: SPACING.sm,
  },
  linkText: {
    fontSize: 12,
    fontWeight: '500',
    color: COLORS.primary,
    textDecorationLine: 'underline',
  },
  restoreText: {
    fontSize: 14,
    fontWeight: '600',
    color: COLORS.primary,
    textAlign: 'center',
    marginTop: SPACING.md,
    marginBottom: SPACING.xl,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: SPACING.lg,
  },
  loadingText: {
    fontSize: 16,
    fontWeight: '500',
    color: COLORS.text,
    marginTop: SPACING.md,
    textAlign: 'center',
  },
  errorContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: SPACING.xl,
  },
  errorIcon: {
    fontSize: 64,
    marginBottom: SPACING.lg,
  },
  errorTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    color: COLORS.text,
    textAlign: 'center',
    marginBottom: SPACING.md,
  },
  errorMessage: {
    fontSize: 16,
    fontWeight: '400',
    color: COLORS.textSecondary,
    textAlign: 'center',
    marginBottom: SPACING.xl,
    lineHeight: 24,
  },
  retryButton: {
    width: '100%',
    marginBottom: SPACING.md,
  },
  errorHint: {
    fontSize: 14,
    fontWeight: '400',
    color: COLORS.textMuted,
    textAlign: 'center',
    marginTop: SPACING.sm,
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
});
