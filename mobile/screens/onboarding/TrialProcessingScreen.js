import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, ActivityIndicator, TouchableOpacity } from 'react-native';
import AnimatedBackground from '../../components/AnimatedBackground';
import QuitOnboardingButton from '../../components/QuitOnboardingButton';
import { COLORS, SPACING } from '../../constants/colors';
import { pollTrialSessionStatus, getTrialSessionResults } from '../../services/api';
import { useOnboarding } from '../../context/OnboardingContext';

export default function TrialProcessingScreen({ navigation }) {
  const { onboardingData, updateOnboardingData } = useOnboarding();
  const [progress, setProgress] = useState(0);
  const [currentStep, setCurrentStep] = useState('Starting analysis...');
  const [error, setError] = useState(null);

  const trialToken = onboardingData.trialSessionToken;

  useEffect(() => {
    if (!trialToken) {
      // No trial token - navigate back
      navigation.navigate('TrialRecording');
      return;
    }

    startProcessing();
  }, [trialToken]);

  const startProcessing = async () => {
    try {
      // Poll for completion
      await pollTrialSessionStatus(
        trialToken,
        (progressData) => {
          // Update UI with progress
          setProgress(progressData.progress || 0);
          setCurrentStep(progressData.step || 'Processing...');
        }
      );

      // Processing complete - fetch results
      const trialSession = await getTrialSessionResults(trialToken);

      // Store results in context
      updateOnboardingData({
        trialResults: {
          clarity: trialSession.metrics.clarity,
          wordsPerMinute: trialSession.metrics.wpm,
          fillerWordsPerMinute: trialSession.metrics.filler_words_per_minute,
          fillerRate: trialSession.metrics.filler_rate,
          transcript: trialSession.transcript,
          isMockData: trialSession.is_mock || false,
        },
      });

      // Navigate to results
      navigation.navigate('Results');
    } catch (err) {
      console.error('Processing error:', err);
      setError(err.message || 'Failed to process recording');
    }
  };

  const handleRetry = () => {
    setError(null);
    setProgress(0);
    setCurrentStep('Starting analysis...');
    startProcessing();
  };

  if (error) {
    return (
      <View style={styles.container}>
        <AnimatedBackground />
        <QuitOnboardingButton />
        <View style={styles.content}>
          <Text style={styles.errorIcon}>⚠️</Text>
          <Text style={styles.errorTitle}>Processing Failed</Text>
          <Text style={styles.errorMessage}>{error}</Text>

          <TouchableOpacity style={styles.retryButton} onPress={handleRetry}>
            <Text style={styles.retryButtonText}>Try Again</Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={styles.skipButton}
            onPress={() => navigation.navigate('TrialRecording')}
          >
            <Text style={styles.skipButtonText}>Go Back</Text>
          </TouchableOpacity>
        </View>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <AnimatedBackground />
      <QuitOnboardingButton />
      <View style={styles.content}>
        <Text style={styles.header}>Analyzing Your Speech</Text>
        <Text style={styles.subheader}>
          Our AI is carefully analyzing your recording...
        </Text>

        {/* Processing Animation */}
        <View style={styles.animationContainer}>
          <View style={styles.progressCircle}>
            <ActivityIndicator size="large" color={COLORS.primary} />
            <Text style={styles.progressText}>{progress}%</Text>
          </View>
        </View>

        {/* Current Step */}
        <View style={styles.stepContainer}>
          <Text style={styles.stepText}>{currentStep}</Text>
        </View>

        {/* Processing Steps */}
        <View style={styles.stepsContainer}>
          <ProcessingStep
            label="Upload"
            isComplete={progress > 10}
            isActive={progress <= 10}
          />
          <ProcessingStep
            label="Transcribe"
            isComplete={progress > 40}
            isActive={progress > 10 && progress <= 40}
          />
          <ProcessingStep
            label="Analyze"
            isComplete={progress > 70}
            isActive={progress > 40 && progress <= 70}
          />
          <ProcessingStep
            label="Complete"
            isComplete={progress >= 100}
            isActive={progress > 70 && progress < 100}
          />
        </View>

        {/* Tip */}
        <View style={styles.tipContainer}>
          <Text style={styles.tipText}>
            💡 <Text style={styles.tipBold}>Did you know?</Text> Reducing filler words by just 50% can increase your perceived confidence by up to 30%.
          </Text>
        </View>
      </View>
    </View>
  );
}

const ProcessingStep = ({ label, isComplete, isActive }) => (
  <View style={styles.step}>
    <View style={[
      styles.stepIndicator,
      isComplete && styles.stepComplete,
      isActive && styles.stepActive,
    ]}>
      {isComplete ? (
        <Text style={styles.stepCheckmark}>✓</Text>
      ) : (
        <View style={[styles.stepDot, isActive && styles.stepDotActive]} />
      )}
    </View>
    <Text style={[
      styles.stepLabel,
      (isComplete || isActive) && styles.stepLabelActive
    ]}>
      {label}
    </Text>
  </View>
);

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background,
  },
  content: {
    flex: 1,
    paddingTop: 100,
    paddingHorizontal: SPACING.lg,
    alignItems: 'center',
  },
  header: {
    fontSize: 28,
    fontWeight: 'bold',
    color: COLORS.text,
    marginBottom: SPACING.sm,
    textAlign: 'center',
  },
  subheader: {
    fontSize: 16,
    color: COLORS.textSecondary,
    marginBottom: SPACING.xl,
    textAlign: 'center',
  },
  animationContainer: {
    marginVertical: SPACING.xl * 2,
  },
  progressCircle: {
    width: 120,
    height: 120,
    borderRadius: 60,
    backgroundColor: COLORS.backgroundSecondary,
    alignItems: 'center',
    justifyContent: 'center',
  },
  progressText: {
    fontSize: 20,
    fontWeight: 'bold',
    color: COLORS.primary,
    marginTop: SPACING.sm,
  },
  stepContainer: {
    marginBottom: SPACING.xl,
  },
  stepText: {
    fontSize: 16,
    color: COLORS.text,
    fontWeight: '500',
  },
  stepsContainer: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    width: '100%',
    marginBottom: SPACING.xl * 2,
  },
  step: {
    alignItems: 'center',
  },
  stepIndicator: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: COLORS.backgroundSecondary,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: SPACING.xs,
  },
  stepComplete: {
    backgroundColor: COLORS.success || '#10b981',
  },
  stepActive: {
    backgroundColor: COLORS.primary,
  },
  stepCheckmark: {
    fontSize: 20,
    color: COLORS.background,
    fontWeight: 'bold',
  },
  stepDot: {
    width: 12,
    height: 12,
    borderRadius: 6,
    backgroundColor: COLORS.textSecondary,
    opacity: 0.3,
  },
  stepDotActive: {
    backgroundColor: COLORS.background,
    opacity: 1,
  },
  stepLabel: {
    fontSize: 12,
    color: COLORS.textSecondary,
  },
  stepLabelActive: {
    color: COLORS.text,
    fontWeight: '600',
  },
  tipContainer: {
    backgroundColor: COLORS.backgroundSecondary,
    padding: SPACING.md,
    borderRadius: 12,
    marginTop: SPACING.xl,
  },
  tipText: {
    fontSize: 14,
    color: COLORS.textSecondary,
    textAlign: 'center',
    lineHeight: 20,
  },
  tipBold: {
    fontWeight: '600',
    color: COLORS.text,
  },
  // Error styles
  errorIcon: {
    fontSize: 64,
    marginBottom: SPACING.md,
  },
  errorTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    color: COLORS.text,
    marginBottom: SPACING.sm,
  },
  errorMessage: {
    fontSize: 16,
    color: COLORS.textSecondary,
    textAlign: 'center',
    marginBottom: SPACING.xl,
  },
  retryButton: {
    backgroundColor: COLORS.primary,
    paddingVertical: 16,
    paddingHorizontal: 32,
    borderRadius: 12,
    marginBottom: SPACING.md,
  },
  retryButtonText: {
    color: COLORS.background,
    fontSize: 16,
    fontWeight: '600',
  },
  skipButton: {
    paddingVertical: 12,
  },
  skipButtonText: {
    color: COLORS.textSecondary,
    fontSize: 16,
  },
});
