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
  PRACTICE_PROMPTS,
  TIME_OPTIONS,
  MOCK_WEEKLY_FOCUS,
} from '../../constants/practiceData';
import { createSession, getProgressMetrics } from '../../services/api';

export default function PracticeScreen({ navigation, route }) {
  // Extract route params
  const params = route?.params || {};
  const {
    presetDuration,
    promptText,
    promptTitle,
    drillTitle,
  } = params;

  // Check if we have a custom prompt from navigation params
  const customPrompt = (promptText || drillTitle) ? {
    text: promptText || drillTitle,
    category: promptTitle || 'Practice',
    duration: presetDuration || 60,
  } : null;

  // Prompt state
  const [currentPromptIndex, setCurrentPromptIndex] = useState(0);
  const currentPrompt = customPrompt || PRACTICE_PROMPTS[currentPromptIndex];
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

  const recordingRef = useRef(null);
  const intervalRef = useRef(null);
  const recordingTimeRef = useRef(0); // Track current recording time to avoid stale closure

  useEffect(() => {
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
        }
      } catch (error) {
        console.error('Error requesting audio permissions:', error);
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
      } finally {
        setMetricsLoading(false);
      }
    };

    fetchAverageMetrics();
  }, []);

  // Auto-stop recording when timer completes
  useEffect(() => {
    if (shouldAutoStop && isRecording) {
      console.log('Auto-stopping recording at', recordingTimeRef.current, 'seconds');
      setShouldAutoStop(false); // Reset flag
      stopRecording();
    }
  }, [shouldAutoStop, isRecording]);

  const handleShuffle = () => {
    // Only allow shuffle if not using a custom prompt
    if (canShuffle) {
      const nextIndex = (currentPromptIndex + 1) % PRACTICE_PROMPTS.length;
      setCurrentPromptIndex(nextIndex);
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

      // Upload to backend and navigate to processing screen
      try {
        // TODO: Get actual user ID from auth context
        const userId = 'test-user';

        // Create session title
        const sessionTitle = `Practice Session - ${new Date().toLocaleDateString()}`;

        // Prepare audio file object
        const audioFile = {
          uri,
          name: `recording_${Date.now()}.m4a`,
          type: 'audio/m4a',
        };

        console.log('Uploading session - actual duration:', actualDurationSec, 'seconds, target:', selectedTime, 'seconds');

        // Upload session with target duration (not actual) for validation
        const session = await createSession(audioFile, {
          title: sessionTitle,
          target_seconds: selectedTime, // Use user's selected target time for validation
          language: 'en',
        });

        console.log('Session created successfully:', session.session_id);

        // Navigate to processing screen
        navigation.navigate('SessionProcessing', { sessionId: session.session_id });
      } catch (error) {
        console.error('Failed to upload session:', error);
        Alert.alert(
          'Upload Failed',
          'Could not upload your recording. Please try again.',
          [{ text: 'OK' }]
        );
      }
    } catch (error) {
      console.error('Failed to stop recording:', error);
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

  return (
    <SafeAreaView style={styles.container} edges={['top', 'bottom']}>
      <AnimatedBackground />

      <View style={styles.content}>
        {/* Recommended Prompt Card */}
        <PromptCard prompt={currentPrompt} onShuffle={handleShuffle} canShuffle={canShuffle} />

        {/* Time Selection Pills - Side by side */}
        <View style={styles.timePillsContainer}>
          {TIME_OPTIONS.map((option) => (
            <PillButton
              key={option.value}
              label={option.label}
              isSelected={selectedTime === option.value}
              onPress={() => setSelectedTime(option.value)}
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
        <View style={styles.weeklyFocusSection}>
          <Text style={styles.sectionTitle}>Weekly Focus</Text>
          <WeeklyFocusCard focus={MOCK_WEEKLY_FOCUS} />
        </View>
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
