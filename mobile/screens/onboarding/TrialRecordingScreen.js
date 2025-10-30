import React, { useState, useEffect, useRef } from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, Alert } from 'react-native';
import { Audio } from 'expo-av';
import RecordButton from '../../components/RecordButton';
import { COLORS, SPACING } from '../../constants/colors';
import { TRIAL_PROMPT } from '../../constants/onboardingData';
import { useOnboarding } from '../../context/OnboardingContext';

const RECORDING_DURATION = 30; // 30 seconds

export default function TrialRecordingScreen({ navigation }) {
  const { updateOnboardingData } = useOnboarding();

  const [isRecording, setIsRecording] = useState(false);
  const [recordingTime, setRecordingTime] = useState(0);
  const [progress, setProgress] = useState(0);
  const [hasRecorded, setHasRecorded] = useState(false);

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
        await recordingRef.current.stopAndUnloadAsync();
        const uri = recordingRef.current.getURI();

        // Here you would normally upload to backend
        // For now, just store that we recorded
        console.log('Recording saved at:', uri);

        updateOnboardingData({
          trialSessionToken: 'mock-token', // Would be from API
          // trialResults would be fetched from API
        });

        setHasRecorded(true);

        // Navigate to next screen (Results - not yet implemented)
        // For now, show alert
        Alert.alert(
          'Recording Complete!',
          'Your recording has been saved. (Results screen coming soon)',
          [
            {
              text: 'Continue',
              onPress: () => {
                // TODO: Navigate to Results screen when implemented
                console.log('Would navigate to Results screen');
              },
            },
          ]
        );
      }
    } catch (error) {
      console.error('Failed to stop recording:', error);
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
              trialResults: {
                isMockData: true,
              },
            });
            // TODO: Navigate to Results screen with mock data
            console.log('Would navigate to Results screen with mock data');
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
        <Text style={styles.header}>Let's do a 30s trail</Text>

        {/* Skip button */}
        <TouchableOpacity style={styles.skipButton} onPress={handleSkip}>
          <Text style={styles.skipText}>Skip</Text>
        </TouchableOpacity>

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

          {/* Cancel button (shown during recording) */}
          {isRecording && (
            <TouchableOpacity style={styles.cancelButton} onPress={stopRecording}>
              <Text style={styles.cancelText}>Cancel</Text>
            </TouchableOpacity>
          )}
        </View>

        {/* Pagination dots */}
        <View style={styles.paginationContainer}>
          {[...Array(9)].map((_, index) => (
            <View
              key={index}
              style={[
                styles.dot,
                index === 5 && styles.activeDot, // Screen 6 is active (index 5)
              ]}
            />
          ))}
        </View>
      </ScrollView>
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
    paddingBottom: SPACING.xxl,
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
    top: 20,
    right: SPACING.lg,
    padding: SPACING.sm,
    zIndex: 10,
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
  cancelButton: {
    marginTop: SPACING.lg,
    paddingHorizontal: SPACING.xl,
    paddingVertical: SPACING.sm,
  },
  cancelText: {
    fontSize: 16,
    fontWeight: '600',
    color: COLORS.danger,
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
});
