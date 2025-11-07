import React, { useState, useEffect, useRef } from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, Alert, ActivityIndicator } from 'react-native';
import { Audio } from 'expo-av';
import { SafeAreaView } from 'react-native-safe-area-context';
import PromptCard from '../../components/PromptCard';
import PillButton from '../../components/PillButton';
import RecordButton from '../../components/RecordButton';
import MetricCard from '../../components/MetricCard';
import WeeklyFocusCard from '../../components/WeeklyFocusCard';
import BottomNavigation from '../../components/BottomNavigation';
import AnimatedBackground from '../../components/AnimatedBackground';
import { COLORS, SPACING } from '../../constants/colors';
import {
  TIME_OPTIONS,
  MOCK_WEEKLY_FOCUS,
} from '../../constants/practiceData';
import { createSession, getProgressMetrics, getCoachRecommendations, getDailyPrompt, shufflePrompt } from '../../services/api';
import analytics from '../../services/analytics';
import { useAuth } from '../../context/AuthContext';

export default function PracticeScreen({ navigation, route }) {
  const { user } = useAuth();
  // Extract route params
  const params = route?.params || {};
  const {
    presetDuration,
    promptText,
    promptTitle,
    drillTitle,
    isRetake,
    originalTitle,
    retakeCount,
    relevanceFeedback,
  } = params;

  // Check if we have a custom prompt from navigation params
  const customPrompt = (promptText || drillTitle || originalTitle) ? {
    text: promptText || drillTitle || originalTitle,
    category: promptTitle || 'Practice',
    duration: presetDuration || 60,
  } : null;

  // Prompt state
  const [currentPrompt, setCurrentPrompt] = useState(customPrompt || null);
  const [promptLoading, setPromptLoading] = useState(!customPrompt);
  const canShuffle = !customPrompt; // Disable shuffle when using custom prompt

  // Time selection state
  const [selectedTime, setSelectedTime] = useState(presetDuration || 60); // Use preset or default to 60s

  // Recording state
  const [isRecording, setIsRecording] = useState(false);
  const [recordingTime, setRecordingTime] = useState(0);
  const [progress, setProgress] = useState(0);
  const [shouldAutoStop, setShouldAutoStop] = useState(false); // Flag to trigger auto-stop

  // Average metrics state
  const [averageMetrics, setAverageMetrics] = useState(null);
  const [metricsLoading, setMetricsLoading] = useState(true);

  // Weekly focus state
  const [weeklyFocus, setWeeklyFocus] = useState(null);

  const recordingRef = useRef(null);
  const intervalRef = useRef(null);
  const recordingTimeRef = useRef(0); // Track current recording time to avoid stale closure

  useEffect(() => {
    // Track screen view
    analytics.trackScreen('Practice');

    // Request audio permissions on mount
    (async () => {
      try {
        const { status } = await Audio.requestPermissionsAsync();
        if (status !== 'granted') {
          Alert.alert(
            'Permission Required',
            'We need microphone access to record your speech.',
            [{ text: 'OK' }]
          );

          // Track permission denied
          analytics.track('Microphone Permission Denied');
        } else {
          // Track permission granted
          analytics.track('Microphone Permission Granted');
        }
      } catch (error) {
        console.error('Error requesting audio permissions:', error);
        analytics.track('Microphone Permission Error', {
          error: error.message,
        });
      }
    })();

    return () => {
      // Cleanup on unmount
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
      }
      if (recordingRef.current) {
        recordingRef.current.stopAndUnloadAsync();
      }
    };
  }, []);

  // Fetch daily prompt on mount if not using custom prompt
  useEffect(() => {
    if (!customPrompt) {
      const fetchDailyPrompt = async () => {
        try {
          setPromptLoading(true);
          const prompt = await getDailyPrompt();
          setCurrentPrompt(prompt);
        } catch (error) {
          console.error('Error fetching daily prompt:', error);
          // Fallback to default prompt
          setCurrentPrompt({
            text: 'What did you enjoy most about last week and why?',
            category: 'Reflection',
            duration: 60,
            identifier: 'fallback_default'
          });
        } finally {
          setPromptLoading(false);
        }
      };

      fetchDailyPrompt();
    }
  }, []);

  // Fetch average metrics on mount
  useEffect(() => {
    const fetchAverageMetrics = async () => {
      try {
        setMetricsLoading(true);
        const data = await getProgressMetrics('10_sessions');
        setAverageMetrics(data.average_values);
      } catch (error) {
        console.error('Error fetching average metrics:', error);
        // Set empty object on error so we can show placeholder values
        setAverageMetrics({});
      } finally{
        setMetricsLoading(false);
      }
    };

    fetchAverageMetrics();
  }, []);

  // Fetch weekly focus on mount
  useEffect(() => {
    const fetchWeeklyFocus = async () => {
      try {
        const coachData = await getCoachRecommendations();

        // Transform the API response to match WeeklyFocusCard format
        if (coachData.weekly_focus && coachData.weekly_focus_tracking) {
          const transformedFocus = {
            title: coachData.weekly_focus.title || 'Weekly Practice Goal',
            tip: coachData.weekly_focus.coaching_tip || 'Keep practicing to improve',
            today: {
              completed: coachData.weekly_focus_tracking.sessions_today || 0,
              goal: coachData.weekly_focus_tracking.target_today || 2,
            },
            week: {
              completed: coachData.weekly_focus_tracking.sessions_this_week || 0,
              goal: coachData.weekly_focus_tracking.target_this_week || 10,
            },
            streak: {
              days: coachData.weekly_focus_tracking.streak_days || 0,
            },
          };
          setWeeklyFocus(transformedFocus);
        } else {
          // Use fallback if no weekly focus is set
          setWeeklyFocus(MOCK_WEEKLY_FOCUS);
        }
      } catch (error) {
        console.error('Error fetching weekly focus:', error);
        // Use fallback on error
        setWeeklyFocus(MOCK_WEEKLY_FOCUS);
      }
    };

    fetchWeeklyFocus();
  }, []);

  // Auto-stop recording when timer completes
  useEffect(() => {
    if (shouldAutoStop && isRecording) {
      console.log('Auto-stopping recording at', recordingTimeRef.current, 'seconds');
      setShouldAutoStop(false); // Reset flag
      stopRecording();
    }
  }, [shouldAutoStop, isRecording]);

  const handleShuffle = async () => {
    // Only allow shuffle if not using a custom prompt
    if (canShuffle) {
      try {
        setPromptLoading(true);
        const newPrompt = await shufflePrompt();
        setCurrentPrompt(newPrompt);

        // Track prompt shuffle
        analytics.track('Prompt Shuffled', {
          new_prompt_category: newPrompt.category,
        });
      } catch (error) {
        console.error('Error shuffling prompt:', error);
        Alert.alert('Error', 'Failed to shuffle prompt. Please try again.');
      } finally {
        setPromptLoading(false);
      }
    }
  };

  // Helper functions to format metric values
  const formatOverallScore = (value) => {
    if (!value && value !== 0) return '--';
    return Math.round(value * 100);
  };

  const formatFillerRate = (value) => {
    if (!value && value !== 0) return '--';
    return (value * 100).toFixed(1) + '%';
  };

  const formatWPM = (value) => {
    if (!value && value !== 0) return '--';
    return Math.round(value);
  };

  const startRecording = async () => {
    try {
      // Request permissions
      const { status } = await Audio.requestPermissionsAsync();
      if (status !== 'granted') {
        Alert.alert('Permission denied', 'Cannot record without microphone permission');
        analytics.track('Recording Start Failed', {
          reason: 'permission_denied',
        });
        return;
      }

      // Configure audio mode
      await Audio.setAudioModeAsync({
        allowsRecordingIOS: true,
        playsInSilentModeIOS: true,
      });

      // Start recording
      const { recording } = await Audio.Recording.createAsync(
        Audio.RecordingOptionsPresets.HIGH_QUALITY
      );

      recordingRef.current = recording;
      setIsRecording(true);
      setRecordingTime(0);
      setProgress(0);
      recordingTimeRef.current = 0; // Reset ref

      // Track recording started
      analytics.track('Recording Started', {
        target_duration: selectedTime,
        prompt_category: currentPrompt.category,
        prompt_text: currentPrompt.text,
        source: customPrompt ? 'custom' : 'practice',
      });

      // Start timer
      intervalRef.current = setInterval(() => {
        setRecordingTime((prevTime) => {
          const newTime = prevTime + 1;
          recordingTimeRef.current = newTime; // Update ref to avoid stale closure
          setProgress(newTime / selectedTime);

          // Auto-stop when time is reached
          if (newTime >= selectedTime) {
            if (intervalRef.current) {
              clearInterval(intervalRef.current);
              intervalRef.current = null;
            }
            setShouldAutoStop(true); // Trigger auto-stop via useEffect
          }

          return newTime;
        });
      }, 1000);
    } catch (error) {
      console.error('Failed to start recording:', error);
      Alert.alert('Error', 'Failed to start recording. Please try again.');
    }
  };

  const stopRecording = async () => {
    try {
      // Reset auto-stop flag if it's set
      setShouldAutoStop(false);

      // Clear interval first
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
        intervalRef.current = null;
      }

      if (!recordingRef.current) {
        console.error('No recording reference found');
        return;
      }

      // Get actual duration from recording object BEFORE stopping
      let actualDurationSec = 0;
      try {
        const status = await recordingRef.current.getStatusAsync();
        if (status && status.durationMillis) {
          actualDurationSec = Math.floor(status.durationMillis / 1000);
          console.log('Duration from recording status:', actualDurationSec, 'seconds');
        }
      } catch (statusError) {
        console.warn('Could not get recording status, using ref value:', statusError);
        actualDurationSec = recordingTimeRef.current;
      }

      // Fallback to ref if status duration is 0
      if (actualDurationSec === 0) {
        actualDurationSec = recordingTimeRef.current;
        console.log('Using ref duration as fallback:', actualDurationSec, 'seconds');
      }

      // Stop and get URI
      setIsRecording(false);
      await recordingRef.current.stopAndUnloadAsync();
      const uri = recordingRef.current.getURI();

      console.log('Recording saved at:', uri);
      console.log('Final recording duration:', actualDurationSec, 'seconds');

      // Validate duration
      if (actualDurationSec === 0 || !actualDurationSec) {
        console.error('Invalid recording duration:', actualDurationSec);
        Alert.alert(
          'Recording Error',
          'Recording duration is invalid. Please try recording again.',
          [{ text: 'OK' }]
        );
        // Reset state
        setRecordingTime(0);
        setProgress(0);
        recordingTimeRef.current = 0;
        return;
      }

      // Reset recording state
      setRecordingTime(0);
      setProgress(0);
      recordingTimeRef.current = 0;

      // Track recording stopped
      analytics.track('Recording Stopped', {
        actual_duration: actualDurationSec,
        target_duration: selectedTime,
        completion_percentage: (actualDurationSec / selectedTime) * 100,
        stopped_by: actualDurationSec >= selectedTime ? 'auto' : 'user',
        prompt_category: currentPrompt.category,
      });

      // Prepare audio file object and session options
      const audioFile = {
        uri,
        name: `recording_${Date.now()}.m4a`,
        type: 'audio/m4a',
      };

      const sessionTitle = originalTitle || `Practice Session - ${new Date().toLocaleDateString()}`;
      const sessionOptions = {
        title: sessionTitle,
        prompt_text: currentPrompt?.text, // Actual prompt text for relevance checking
        target_seconds: selectedTime,
        language: user?.preferred_language || 'en',
        retake_count: retakeCount || 0,
        is_retake: isRetake || false,
        prompt_identifier: currentPrompt?.identifier, // Track which prompt was used
      };

      console.log('Navigating to processing screen with audio file');

      // Navigate to processing screen IMMEDIATELY - let it handle the upload
      navigation.navigate('SessionProcessing', {
        audioFile,
        sessionOptions,
      });
    } catch (error) {
      console.error('Failed to stop recording:', error);

      // Track recording error
      analytics.track('Recording Error', {
        error: error.message,
        stage: 'stop',
      });

      Alert.alert('Error', 'Failed to stop recording. Please try again.');
    }
  };

  const handleRecordPress = () => {
    if (isRecording) {
      stopRecording();
    } else {
      startRecording();
    }
  };

  const handleTimeSelection = (duration) => {
    setSelectedTime(duration);

    // Track time duration selection
    analytics.track('Time Duration Selected', {
      duration_seconds: duration,
      duration_label: TIME_OPTIONS.find(opt => opt.value === duration)?.label,
    });
  };

  return (
    <SafeAreaView style={styles.container} edges={['top', 'bottom']}>
      <AnimatedBackground />

      <View style={styles.content}>
        {/* Retake Banner */}
        {isRetake && relevanceFeedback && (
          <View style={styles.retakeBanner}>
            <Text style={styles.retakeBannerTitle}>💡 Try Again - Stay On Topic</Text>
            <Text style={styles.retakeBannerText}>{relevanceFeedback}</Text>
            <Text style={styles.retakeBannerPrompt}>Focus on: {originalTitle}</Text>
          </View>
        )}

        {/* Recommended Prompt Card */}
        <PromptCard prompt={currentPrompt} onShuffle={handleShuffle} canShuffle={canShuffle} />

        {/* Time Selection Pills - Side by side */}
        <View style={styles.timePillsContainer}>
          {TIME_OPTIONS.map((option) => (
            <PillButton
              key={option.value}
              label={option.label}
              isSelected={selectedTime === option.value}
              onPress={() => handleTimeSelection(option.value)}
              style={styles.pillButton}
            />
          ))}
        </View>

        {/* Recording Section - Horizontal Layout */}
        <View style={styles.recordingSection}>
          <View style={styles.recordButtonWrapper}>
            <RecordButton
              isRecording={isRecording}
              onPress={handleRecordPress}
              progress={progress}
            />
          </View>

          <View style={styles.timerContainer}>
            <Text style={styles.timerText}>
              {recordingTime}s / {selectedTime}s
            </Text>
          </View>
        </View>

        {/* Last 10 Sessions Average */}
        <View style={styles.averageSection}>
          <Text style={styles.sectionTitle}>Last 10 Sessions</Text>
          {metricsLoading ? (
            <View style={styles.loadingContainer}>
              <ActivityIndicator size="small" color={COLORS.primary} />
            </View>
          ) : (
            <View style={styles.metricsRow}>
              <MetricCard
                icon={null}
                label="Overall"
                value={formatOverallScore(averageMetrics?.overall_score)}
                style={styles.metricCard}
              />
              <MetricCard
                icon={null}
                label="Filler"
                value={formatFillerRate(averageMetrics?.filler_rate)}
                style={styles.metricCard}
              />
              <MetricCard
                icon={null}
                label="Words/min"
                value={formatWPM(averageMetrics?.wpm)}
                style={styles.metricCard}
              />
            </View>
          )}
        </View>

        {/* Weekly Focus Section */}
        {weeklyFocus && (
          <View style={styles.weeklyFocusSection}>
            <Text style={styles.sectionTitle}>Weekly Focus</Text>
            <WeeklyFocusCard focus={weeklyFocus} />
          </View>
        )}
      </View>

      {/* Bottom Navigation */}
      <BottomNavigation activeScreen="practice" />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background,
  },
  content: {
    paddingHorizontal: SPACING.lg,
    paddingTop: 4,
    paddingBottom: 100, // Add space for floating navigation bar
  },
  retakeBanner: {
    backgroundColor: '#FFF3CD',
    borderRadius: 12,
    padding: 16,
    marginBottom: 16,
    borderWidth: 1,
    borderColor: '#FFD700',
  },
  retakeBannerTitle: {
    fontSize: 16,
    fontWeight: '700',
    color: '#856404',
    marginBottom: 8,
  },
  retakeBannerText: {
    fontSize: 14,
    color: '#856404',
    marginBottom: 8,
    lineHeight: 20,
  },
  retakeBannerPrompt: {
    fontSize: 14,
    fontWeight: '600',
    color: '#856404',
    fontStyle: 'italic',
  },
  timePillsContainer: {
    flexDirection: 'row',
    justifyContent: 'center',
    marginTop: SPACING.sm,
    marginBottom: SPACING.xs,
    gap: 6,
  },
  pillButton: {
    marginRight: 0,
    marginBottom: 0,
    minWidth: 60,
  },
  recordingSection: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: -SPACING.md,
    marginBottom: -SPACING.sm,
  },
  recordButtonWrapper: {
    // RecordButton is 220x220, we'll scale it down and center it
    transform: [{ scale: 0.65 }],
    alignSelf: 'center',
  },
  timerContainer: {
    position: 'absolute',
    right: SPACING.lg,
    alignItems: 'flex-end',
    justifyContent: 'center',
  },
  timerText: {
    fontSize: 16,
    fontWeight: '600',
    color: COLORS.text,
  },
  averageSection: {
    marginTop: 4,
    marginBottom: SPACING.sm,
  },
  sectionTitle: {
    fontSize: 13,
    fontWeight: '600',
    color: COLORS.text,
    marginBottom: SPACING.xs,
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
  metricsRow: {
    flexDirection: 'row',
    gap: SPACING.xs,
  },
  metricCard: {
    flex: 1,
  },
  loadingContainer: {
    paddingVertical: SPACING.lg,
    alignItems: 'center',
    justifyContent: 'center',
  },
  weeklyFocusSection: {
    marginTop: SPACING.xs,
    marginBottom: SPACING.sm,
  },
});
