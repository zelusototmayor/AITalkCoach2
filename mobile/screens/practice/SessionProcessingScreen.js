import React, { useEffect, useState, useRef } from 'react';
import { View, Text, StyleSheet, ActivityIndicator } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import AnimatedBackground from '../../components/AnimatedBackground';
import { COLORS, SPACING } from '../../constants/colors';
import { createSession, pollSessionStatus, getProcessingStage, getSessionReport } from '../../services/api';
import analytics from '../../services/analytics';

export default function SessionProcessingScreen({ route, navigation }) {
  const { sessionId: initialSessionId, audioFile, sessionOptions } = route.params;

  const [sessionId, setSessionId] = useState(initialSessionId);
  const [progressPercent, setProgressPercent] = useState(0);
  const [processingState, setProcessingState] = useState('pending');
  const [stageInfo, setStageInfo] = useState({
    stage: 1,
    name: 'Uploading',
    description: 'Uploading your recording...',
  });
  const [error, setError] = useState(null);
  const startTimeRef = useRef(null);
  const lastMilestoneRef = useRef(0);

  useEffect(() => {
    const startProcessing = async () => {
      try {
        startTimeRef.current = Date.now();
        let currentSessionId = sessionId;

        // Track processing started
        analytics.track('Session Processing Started', {
          has_audio_file: !!audioFile,
          initial_session_id: initialSessionId,
        });

        // If we have audioFile, upload it first
        if (audioFile && sessionOptions) {
          console.log('Uploading session from processing screen...');
          setStageInfo({
            stage: 1,
            name: 'Uploading',
            description: 'Uploading your recording...',
          });

          analytics.track('Session Upload Started', {
            target_duration: sessionOptions.target_seconds,
          });

          const uploadStartTime = Date.now();
          const session = await createSession(audioFile, sessionOptions);
          currentSessionId = session.session_id;
          setSessionId(currentSessionId);
          console.log('Session created:', currentSessionId);

          // Track upload completed
          analytics.track('Session Upload Completed', {
            session_id: currentSessionId,
            upload_duration_ms: Date.now() - uploadStartTime,
          });
        }

        if (!currentSessionId) {
          throw new Error('No session ID available');
        }

        // Start polling for session status
        const completeSession = await pollSessionStatus(
          currentSessionId,
          (progress) => {
            // Update progress in real-time
            setProgressPercent(progress.progress_percent);
            setProcessingState(progress.processing_state);
            setStageInfo(getProcessingStage(progress.progress_percent));

            // Track progress milestones (every 25%)
            const currentMilestone = Math.floor(progress.progress_percent / 25) * 25;
            if (currentMilestone > lastMilestoneRef.current && currentMilestone > 0) {
              analytics.track('Session Processing Progress', {
                session_id: currentSessionId,
                progress_percent: currentMilestone,
                stage: getProcessingStage(progress.progress_percent).name,
              });
              lastMilestoneRef.current = currentMilestone;
            }
          },
          1500 // Poll every 1.5 seconds for more responsive updates
        );

        // Processing complete - fetch full session data
        const fullSession = await getSessionReport(currentSessionId);

        // Check if session failed relevance check
        if (fullSession.session && fullSession.session.processing_state === 'relevance_failed') {
          // Track relevance failure
          analytics.track('Session Relevance Failed', {
            session_id: currentSessionId,
            relevance_score: fullSession.session.relevance_score,
            retake_count: fullSession.session.retake_count || 0,
          });

          // Navigate to relevance screen for user decision
          navigation.replace('SessionRelevance', {
            session: fullSession.session
          });
          return;
        }

        // Check if session is incomplete (too short)
        if (fullSession.session && !fullSession.session.completed && fullSession.session.incomplete_reason) {
          // Track session incomplete
          analytics.track('Session Incomplete', {
            session_id: currentSessionId,
            reason: fullSession.session.incomplete_reason,
            duration_ms: fullSession.session.duration_ms,
          });

          // Session was too short - show error and go back
          setError(fullSession.session.incomplete_reason);
          setTimeout(() => {
            navigation.goBack();
          }, 3000);
        } else {
          // Track successful processing completion
          analytics.track('Session Processing Completed', {
            session_id: currentSessionId,
            total_duration_ms: Date.now() - startTimeRef.current,
            final_progress: progressPercent,
          });

          // Session completed successfully - navigate to report screen
          setTimeout(() => {
            navigation.replace('SessionReport', { sessionId: currentSessionId, sessionData: fullSession });
          }, 500);
        }
      } catch (err) {
        console.error('Processing error:', err);

        // Track processing failure
        analytics.track('Session Processing Failed', {
          session_id: sessionId,
          error: err.message || 'Unknown error',
          stage: stageInfo.name,
          progress_percent: progressPercent,
        });

        setError(err.message || 'Failed to process your recording');
      }
    };

    startProcessing();
  }, []);

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
              <Text style={styles.progressStage}>Stage {stageInfo.stage}/7</Text>
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
            name="Relevance Check"
            isComplete={progressPercent > 45}
            isCurrent={progressPercent > 35 && progressPercent <= 45}
          />
          <StageItem
            number={4}
            name="Rule Analysis"
            isComplete={progressPercent > 60}
            isCurrent={progressPercent > 45 && progressPercent <= 60}
          />
          <StageItem
            number={5}
            name="AI Refinement"
            isComplete={progressPercent > 80}
            isCurrent={progressPercent > 60 && progressPercent <= 80}
          />
          <StageItem
            number={6}
            name="Metrics Calculation"
            isComplete={progressPercent >= 100}
            isCurrent={progressPercent > 80 && progressPercent < 100}
          />
          <StageItem
            number={7}
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
