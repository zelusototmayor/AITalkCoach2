import React, { useState, useEffect, useRef } from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, Alert } from 'react-native';
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
  MOCK_SEVEN_DAY_METRICS,
  MOCK_WEEKLY_FOCUS,
} from '../../constants/practiceData';

export default function PracticeScreen({ navigation }) {
  // Prompt state
  const [currentPromptIndex, setCurrentPromptIndex] = useState(0);
  const currentPrompt = PRACTICE_PROMPTS[currentPromptIndex];

  // Time selection state
  const [selectedTime, setSelectedTime] = useState(60); // Default to 60s

  // Recording state
  const [isRecording, setIsRecording] = useState(false);
  const [recordingTime, setRecordingTime] = useState(0);
  const [progress, setProgress] = useState(0);

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

  const handleShuffle = () => {
    const nextIndex = (currentPromptIndex + 1) % PRACTICE_PROMPTS.length;
    setCurrentPromptIndex(nextIndex);
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

      // Start timer
      intervalRef.current = setInterval(() => {
        setRecordingTime((prevTime) => {
          const newTime = prevTime + 1;
          setProgress(newTime / selectedTime);

          // Auto-stop when time is reached
          if (newTime >= selectedTime) {
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

        console.log('Recording saved at:', uri);

        // TODO: Upload to backend and get real results
        // For now, show success message
        Alert.alert(
          'Recording Complete!',
          `Great job! You recorded for ${recordingTime} seconds.`,
          [{ text: 'OK' }]
        );

        // Reset recording state
        setRecordingTime(0);
        setProgress(0);
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

  const handleNavigation = (screen) => {
    // TODO: Implement navigation to other screens
    Alert.alert('Coming Soon', `${screen} screen is under development`);
  };

  return (
    <SafeAreaView style={styles.container} edges={['top', 'bottom']}>
      <AnimatedBackground />

      <View style={styles.content}>
        {/* Recommended Prompt Card */}
        <PromptCard prompt={currentPrompt} onShuffle={handleShuffle} />

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

        {/* Average 7 Days Section */}
        <View style={styles.averageSection}>
          <Text style={styles.sectionTitle}>Average 7 Days</Text>
          <View style={styles.metricsRow}>
            <MetricCard
              icon={MOCK_SEVEN_DAY_METRICS.overall.icon}
              label={MOCK_SEVEN_DAY_METRICS.overall.label}
              value={MOCK_SEVEN_DAY_METRICS.overall.value}
              style={styles.metricCard}
            />
            <MetricCard
              icon={MOCK_SEVEN_DAY_METRICS.filler.icon}
              label={MOCK_SEVEN_DAY_METRICS.filler.label}
              value={MOCK_SEVEN_DAY_METRICS.filler.value}
              style={styles.metricCard}
            />
            <MetricCard
              icon={MOCK_SEVEN_DAY_METRICS.wpm.icon}
              label={MOCK_SEVEN_DAY_METRICS.wpm.label}
              value={MOCK_SEVEN_DAY_METRICS.wpm.value}
              style={styles.metricCard}
            />
          </View>
        </View>

        {/* Weekly Focus Section */}
        <View style={styles.weeklyFocusSection}>
          <Text style={styles.sectionTitle}>Weekly Focus</Text>
          <WeeklyFocusCard focus={MOCK_WEEKLY_FOCUS} />
        </View>
      </View>

      {/* Bottom Navigation */}
      <BottomNavigation activeScreen="practice" onNavigate={handleNavigation} />
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
    // RecordButton is 220x220, we'll scale it down
    transform: [{ scale: 0.65 }],
  },
  timerContainer: {
    marginLeft: SPACING.sm,
    alignItems: 'flex-start',
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
  weeklyFocusSection: {
    marginTop: SPACING.xs,
    marginBottom: SPACING.sm,
  },
});
