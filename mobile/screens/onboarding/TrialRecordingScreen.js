import React, { useState, useEffect, useRef } from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, Alert } from 'react-native';
import { Audio } from 'expo-av';
import RecordButton from '../../components/RecordButton';
import AnimatedBackground from '../../components/AnimatedBackground';
import QuitOnboardingButton from '../../components/QuitOnboardingButton';
import { COLORS, SPACING } from '../../constants/colors';
import { TRIAL_PROMPT, MOCK_TRIAL_RESULTS } from '../../constants/onboardingData';
import { useOnboarding } from '../../context/OnboardingContext';
import { createTrialSession } from '../../services/api';
import { useAuth } from '../../context/AuthContext';

const RECORDING_DURATION = 30; // 30 seconds

export default function TrialRecordingScreen({ navigation }) {
  const { updateOnboardingData } = useOnboarding();
  const { getAccessToken } = useAuth();

  const [isRecording, setIsRecording] = useState(false);
  const [recordingTime, setRecordingTime] = useState(0);
  const [progress, setProgress] = useState(0);
  const [hasRecorded, setHasRecorded] = useState(false);
  const [isUploading, setIsUploading] = useState(false);

  const recordingRef = useRef(null);
  const intervalRef = useRef(null);

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

      // Start timer
      intervalRef.current = setInterval(() => {
        setRecordingTime((prevTime) => {
          const newTime = prevTime + 1;
          setProgress(newTime / RECORDING_DURATION);

          // Auto-stop at 30 seconds
          if (newTime >= RECORDING_DURATION) {
            stopRecording();
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
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
      }

      if (recordingRef.current) {
        setIsRecording(false);
        setIsUploading(true);

        await recordingRef.current.stopAndUnloadAsync();
        const uri = recordingRef.current.getURI();

        console.log('Recording saved at:', uri);

        // Upload to backend and get trial token
        const response = await createTrialSession(
          {
            uri: uri,
            name: 'trial-recording.m4a',
            type: 'audio/m4a',
          },
          {
            language: 'en',
            target_seconds: RECORDING_DURATION,
          }
        );

        console.log('Trial session created:', response.trial_token);

        // Store trial token in context
        updateOnboardingData({
          trialSessionToken: response.trial_token,
        });

        setHasRecorded(true);
        setIsUploading(false);

        // Navigate to processing screen
        navigation.navigate('TrialProcessing');
      }
    } catch (error) {
      console.error('Failed to upload recording:', error);
      setIsUploading(false);

      Alert.alert(
        'Upload Failed',
        'Failed to upload your recording. Would you like to try again?',
        [
          {
            text: 'Try Again',
            onPress: () => {
              setHasRecorded(false);
              setRecordingTime(0);
              setProgress(0);
            },
          },
          {
            text: 'Skip',
            style: 'cancel',
            onPress: () => {
              // Use mock data
              updateOnboardingData({
                trialResults: MOCK_TRIAL_RESULTS,
              });
              navigation.navigate('Results');
            },
          },
        ]
      );
    }
  };

  const handleRestart = async () => {
    try {
      // Stop and clean up current recording
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
      }

      if (recordingRef.current) {
        await recordingRef.current.stopAndUnloadAsync();
        recordingRef.current = null;
      }

      // Reset all state
      setIsRecording(false);
      setRecordingTime(0);
      setProgress(0);
      setHasRecorded(false);
    } catch (error) {
      console.error('Failed to restart recording:', error);
    }
  };

  const handleRecordPress = () => {
    if (isRecording) {
      stopRecording();
    } else {
      startRecording();
    }
  };

  const handleSkip = () => {
    Alert.alert(
      'Skip Recording?',
      'You can skip and see example results, or record now for personalized feedback.',
      [
        {
          text: 'Record Now',
          style: 'cancel',
        },
        {
          text: 'Skip',
          onPress: () => {
            updateOnboardingData({
              trialResults: MOCK_TRIAL_RESULTS,
            });
            // Navigate to Results screen with mock data
            navigation.navigate('Results');
          },
        },
      ]
    );
  };

  return (
    <View style={styles.container}>
      <AnimatedBackground />
      <QuitOnboardingButton />
      <ScrollView
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}
      >
        <Text style={styles.header}>Let's do a 30s trail</Text>

        {/* Prompt card */}
        <View style={styles.promptCard}>
          <View style={styles.promptHeader}>
            <Text style={styles.promptLabel}>Prompt</Text>
            <Text style={styles.timerBadge}>30s</Text>
          </View>
          <Text style={styles.promptText}>{TRIAL_PROMPT}</Text>
        </View>

        {/* Record button */}
        <View style={styles.recordContainer}>
          <RecordButton
            isRecording={isRecording}
            onPress={handleRecordPress}
            progress={progress}
          />

          {/* Timer display */}
          <Text style={styles.timerText}>
            {recordingTime}s / {RECORDING_DURATION}s
          </Text>

          {/* Restart button (shown during recording) */}
          {isRecording && (
            <TouchableOpacity style={styles.restartButton} onPress={handleRestart}>
              <Text style={styles.restartText}>Restart</Text>
            </TouchableOpacity>
          )}
        </View>

      </ScrollView>

      {/* Pagination dots - fixed at bottom */}
      <View style={styles.paginationContainer}>
        <View style={styles.dotsWrapper}>
          {[...Array(8)].map((_, index) => (
            <View
              key={index}
              style={[
                styles.dot,
                index === 4 && styles.activeDot,
              ]}
            />
          ))}
        </View>
      </View>

      {/* Skip button - bottom right */}
      <TouchableOpacity style={styles.skipButton} onPress={handleSkip}>
        <Text style={styles.skipText}>Skip</Text>
      </TouchableOpacity>
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
    paddingBottom: 140,
  },
  header: {
    fontSize: 28,
    fontWeight: 'bold',
    color: COLORS.text,
    textAlign: 'center',
    marginBottom: SPACING.lg,
    lineHeight: 36,
  },
  skipButton: {
    position: 'absolute',
    bottom: 80,
    right: SPACING.lg,
    padding: SPACING.md,
    zIndex: 10,
    backgroundColor: COLORS.background,
    borderRadius: 8,
  },
  skipText: {
    fontSize: 16,
    fontWeight: '600',
    color: COLORS.primary,
  },
  promptCard: {
    backgroundColor: COLORS.cardBackground,
    borderRadius: 16,
    borderWidth: 1,
    borderColor: COLORS.border,
    padding: SPACING.lg,
    marginBottom: SPACING.xxl,
    shadowColor: COLORS.text,
    shadowOffset: {
      width: 0,
      height: 1,
    },
    shadowOpacity: 0.05,
    shadowRadius: 3,
    elevation: 2,
  },
  promptHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.sm,
  },
  promptLabel: {
    fontSize: 14,
    fontWeight: '600',
    color: COLORS.textSecondary,
    textTransform: 'uppercase',
  },
  timerBadge: {
    fontSize: 14,
    fontWeight: 'bold',
    color: COLORS.primary,
    backgroundColor: COLORS.selectedBackground,
    paddingHorizontal: SPACING.sm,
    paddingVertical: 4,
    borderRadius: 8,
  },
  promptText: {
    fontSize: 16,
    fontWeight: '500',
    color: COLORS.text,
    lineHeight: 24,
  },
  recordContainer: {
    alignItems: 'center',
    justifyContent: 'center',
    marginVertical: SPACING.xxl,
  },
  timerText: {
    fontSize: 18,
    fontWeight: '600',
    color: COLORS.text,
    marginTop: SPACING.lg,
  },
  restartButton: {
    marginTop: SPACING.lg,
    paddingHorizontal: SPACING.xl,
    paddingVertical: SPACING.sm,
  },
  restartText: {
    fontSize: 16,
    fontWeight: '600',
    color: COLORS.primary,
  },
  paginationContainer: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    paddingHorizontal: SPACING.lg,
    paddingBottom: SPACING.xl,
    paddingTop: SPACING.md,
    pointerEvents: 'box-none',
  },
  dotsWrapper: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    gap: SPACING.xs,
    paddingVertical: SPACING.sm,
  },
  dot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: COLORS.border,
  },
  activeDot: {
    backgroundColor: COLORS.primary,
    width: 24,
    height: 8,
    borderRadius: 4,
  },
});
