import React, { useEffect, useState } from 'react';
import { View, Text, StyleSheet, ActivityIndicator } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import AnimatedBackground from '../../components/AnimatedBackground';
import { COLORS, SPACING } from '../../constants/colors';
import { pollSessionStatus, getProcessingStage, getSessionReport } from '../../services/api';

export default function SessionProcessingScreen({ route, navigation }) {
  const { sessionId } = route.params;

  const [progressPercent, setProgressPercent] = useState(0);
  const [processingState, setProcessingState] = useState('pending');
  const [stageInfo, setStageInfo] = useState({
    stage: 1,
    name: 'Media Extraction',
    description: 'Extracting audio from your recording...',
  });
  const [error, setError] = useState(null);

  useEffect(() => {
    // Start polling for session status
    const startPolling = async () => {
      try {
        const completeSession = await pollSessionStatus(
          sessionId,
          (progress) => {
            // Update progress in real-time
            setProgressPercent(progress.progress_percent);
            setProcessingState(progress.processing_state);
            setStageInfo(getProcessingStage(progress.progress_percent));
          },
          3000 // Poll every 3 seconds
        );

        // Processing complete - fetch full session data
        const fullSession = await getSessionReport(sessionId);

        // Check if session is incomplete (too short)
        if (fullSession.session && !fullSession.session.completed && fullSession.session.incomplete_reason) {
          // Session was too short - show error and go back
          setError(fullSession.session.incomplete_reason);
          setTimeout(() => {
            navigation.goBack();
          }, 3000);
        } else {
          // Session completed successfully - navigate to report screen
          setTimeout(() => {
            navigation.replace('SessionReport', { sessionId, sessionData: fullSession });
          }, 500);
        }
      } catch (err) {
        console.error('Processing error:', err);
        setError(err.message || 'Failed to process your recording');
      }
    };

    startPolling();
  }, [sessionId, navigation]);

  if (error) {
    return (
      <SafeAreaView style={styles.container} edges={['top', 'bottom']}>
        <AnimatedBackground />
        <View style={styles.content}>
          <View style={styles.errorContainer}>
            <Text style={styles.errorIcon}>⚠️</Text>
            <Text style={styles.errorTitle}>Processing Failed</Text>
            <Text style={styles.errorMessage}>{error}</Text>
            <Text style={styles.errorHint}>Please try recording again</Text>
          </View>
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container} edges={['top', 'bottom']}>
      <AnimatedBackground />

      <View style={styles.content}>
        {/* Header */}
        <Text style={styles.title}>Analyzing Your Session</Text>
        <Text style={styles.subtitle}>
          This will take about 30-60 seconds
        </Text>

        {/* Progress Circle */}
        <View style={styles.progressContainer}>
          <View style={styles.progressCircle}>
            <View style={styles.progressInner}>
              <Text style={styles.progressPercent}>{Math.round(progressPercent)}%</Text>
              <Text style={styles.progressStage}>Stage {stageInfo.stage}/6</Text>
            </View>
          </View>

          {/* Progress Bar */}
          <View style={styles.progressBarContainer}>
            <View
              style={[
                styles.progressBarFill,
                { width: `${progressPercent}%` },
              ]}
            />
          </View>
        </View>

        {/* Current Stage Info */}
        <View style={styles.stageContainer}>
          <View style={styles.stageBadge}>
            <Text style={styles.stageBadgeText}>{stageInfo.name}</Text>
          </View>
          <Text style={styles.stageDescription}>{stageInfo.description}</Text>
        </View>

        {/* Processing Stages List */}
        <View style={styles.stagesListContainer}>
          <StageItem
            number={1}
            name="Media Extraction"
            isComplete={progressPercent > 15}
            isCurrent={progressPercent <= 15}
          />
          <StageItem
            number={2}
            name="Transcription"
            isComplete={progressPercent > 35}
            isCurrent={progressPercent > 15 && progressPercent <= 35}
          />
          <StageItem
            number={3}
            name="Rule Analysis"
            isComplete={progressPercent > 60}
            isCurrent={progressPercent > 35 && progressPercent <= 60}
          />
          <StageItem
            number={4}
            name="AI Refinement"
            isComplete={progressPercent > 80}
            isCurrent={progressPercent > 60 && progressPercent <= 80}
          />
          <StageItem
            number={5}
            name="Metrics Calculation"
            isComplete={progressPercent >= 100}
            isCurrent={progressPercent > 80 && progressPercent < 100}
          />
          <StageItem
            number={6}
            name="Complete"
            isComplete={progressPercent >= 100}
            isCurrent={progressPercent >= 100}
          />
        </View>
      </View>
    </SafeAreaView>
  );
}

function StageItem({ number, name, isComplete, isCurrent }) {
  return (
    <View style={styles.stageItem}>
      <View
        style={[
          styles.stageNumber,
          isComplete && styles.stageNumberComplete,
          isCurrent && styles.stageNumberCurrent,
        ]}
      >
        {isComplete ? (
          <Text style={styles.stageCheckmark}>✓</Text>
        ) : (
          <Text
            style={[
              styles.stageNumberText,
              isCurrent && styles.stageNumberTextCurrent,
            ]}
          >
            {number}
          </Text>
        )}
      </View>
      <Text
        style={[
          styles.stageName,
          isComplete && styles.stageNameComplete,
          isCurrent && styles.stageNameCurrent,
        ]}
      >
        {name}
      </Text>
      {isCurrent && <ActivityIndicator size="small" color={COLORS.primary} style={styles.stageSpinner} />}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background,
  },
  content: {
    flex: 1,
    paddingHorizontal: SPACING.lg,
    paddingTop: SPACING.xl,
    alignItems: 'center',
  },
  title: {
    fontSize: 28,
    fontWeight: '700',
    color: COLORS.text,
    textAlign: 'center',
    marginBottom: SPACING.xs,
  },
  subtitle: {
    fontSize: 16,
    color: COLORS.textSecondary,
    textAlign: 'center',
    marginBottom: SPACING.xl,
  },
  progressContainer: {
    alignItems: 'center',
    marginVertical: SPACING.xl,
    width: '100%',
  },
  progressCircle: {
    width: 160,
    height: 160,
    borderRadius: 80,
    backgroundColor: COLORS.cardBackground,
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 8,
    borderColor: COLORS.primary + '30',
    marginBottom: SPACING.lg,
  },
  progressInner: {
    alignItems: 'center',
  },
  progressPercent: {
    fontSize: 48,
    fontWeight: '700',
    color: COLORS.primary,
  },
  progressStage: {
    fontSize: 14,
    color: COLORS.textSecondary,
    marginTop: 4,
  },
  progressBarContainer: {
    width: '100%',
    height: 8,
    backgroundColor: COLORS.cardBackground,
    borderRadius: 4,
    overflow: 'hidden',
  },
  progressBarFill: {
    height: '100%',
    backgroundColor: COLORS.primary,
    borderRadius: 4,
  },
  stageContainer: {
    alignItems: 'center',
    marginTop: SPACING.lg,
    marginBottom: SPACING.xl,
  },
  stageBadge: {
    backgroundColor: COLORS.primary + '20',
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.xs,
    borderRadius: 20,
    marginBottom: SPACING.sm,
  },
  stageBadgeText: {
    fontSize: 14,
    fontWeight: '600',
    color: COLORS.primary,
  },
  stageDescription: {
    fontSize: 16,
    color: COLORS.textSecondary,
    textAlign: 'center',
  },
  stagesListContainer: {
    width: '100%',
    marginTop: SPACING.lg,
  },
  stageItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: SPACING.sm,
  },
  stageNumber: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: COLORS.cardBackground,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: SPACING.md,
    borderWidth: 2,
    borderColor: 'transparent',
  },
  stageNumberComplete: {
    backgroundColor: COLORS.success,
    borderColor: COLORS.success,
  },
  stageNumberCurrent: {
    borderColor: COLORS.primary,
    backgroundColor: COLORS.primary + '10',
  },
  stageNumberText: {
    fontSize: 14,
    fontWeight: '600',
    color: COLORS.textSecondary,
  },
  stageNumberTextCurrent: {
    color: COLORS.primary,
  },
  stageCheckmark: {
    fontSize: 18,
    color: COLORS.white,
  },
  stageName: {
    flex: 1,
    fontSize: 16,
    color: COLORS.textSecondary,
  },
  stageNameComplete: {
    color: COLORS.text,
    opacity: 0.6,
  },
  stageNameCurrent: {
    color: COLORS.text,
    fontWeight: '600',
  },
  stageSpinner: {
    marginLeft: SPACING.sm,
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
    fontWeight: '700',
    color: COLORS.text,
    marginBottom: SPACING.sm,
  },
  errorMessage: {
    fontSize: 16,
    color: COLORS.textSecondary,
    textAlign: 'center',
    marginBottom: SPACING.xs,
  },
  errorHint: {
    fontSize: 14,
    color: COLORS.textSecondary,
    textAlign: 'center',
  },
});
