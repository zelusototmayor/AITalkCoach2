import React, { useState, useEffect, useRef } from 'react';
import { View, Text, StyleSheet, ScrollView, Alert } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Audio, AVPlaybackStatus } from 'expo-av';
import AnimatedBackground from '../../components/AnimatedBackground';
import MetricScorecard from '../../components/MetricScorecard';
import CoachRecommendationCard from '../../components/CoachRecommendationCard';
import AccordionSection from '../../components/AccordionSection';
import IssuesListContent from '../../components/IssuesListContent';
import SecondaryMetricsContent from '../../components/SecondaryMetricsContent';
import TranscriptContent from '../../components/TranscriptContent';
import MetricInfoModal from '../../components/MetricInfoModal';
import BottomNavigation from '../../components/BottomNavigation';
import { COLORS, SPACING } from '../../constants/colors';
import { getSessionReport, getCoachRecommendations, getCurrentWeeklyFocus } from '../../services/api';

export default function SessionReportScreen({ route, navigation }) {
  const { sessionId, sessionData: initialData } = route.params;

  // State
  const [sessionData, setSessionData] = useState(initialData || null);
  const [coachRecommendation, setCoachRecommendation] = useState(null);
  const [weeklyFocus, setWeeklyFocus] = useState(null);
  const [previousSession, setPreviousSession] = useState(null);
  const [loading, setLoading] = useState(!initialData);
  const [selectedMetric, setSelectedMetric] = useState(null);

  // Audio player
  const [sound, setSound] = useState(null);
  const [audioUri, setAudioUri] = useState(null);

  // Fetch session data if not provided
  useEffect(() => {
    const fetchData = async () => {
      try {
        if (!sessionData) {
          const data = await getSessionReport(sessionId);
          setSessionData(data);
        }

        // TODO: Replace with actual user ID from auth context
        const userId = sessionData?.user_id || 'test-user';

        // Fetch coach recommendations and weekly focus
        const [recommendations, focus] = await Promise.all([
          getCoachRecommendations(userId),
          getCurrentWeeklyFocus(userId).catch(() => null), // Gracefully handle missing route
        ]);

        setCoachRecommendation(recommendations);
        setWeeklyFocus(focus);

        // TODO: Fetch previous session for comparison
        // For now, we'll skip this

        setLoading(false);
      } catch (error) {
        console.error('Error fetching session data:', error);
        Alert.alert('Error', 'Failed to load session report');
        setLoading(false);
      }
    };

    fetchData();

    return () => {
      // Cleanup audio on unmount
      if (sound) {
        sound.unloadAsync();
      }
    };
  }, [sessionId]);

  // Handle seeking audio to specific timestamp
  const seekToTimestamp = async (timestampMs) => {
    try {
      if (!sound) {
        // Load audio if not already loaded
        // TODO: Get audio URI from session data
        Alert.alert('Audio Player', 'Audio playback feature coming soon!');
        return;
      }

      await sound.setPositionAsync(timestampMs);
      await sound.playAsync();
    } catch (error) {
      console.error('Error seeking audio:', error);
    }
  };

  // Handle viewing full coaching plan
  const handleViewPlan = () => {
    // TODO: Navigate to coaching plan screen
    Alert.alert('Coming Soon', 'Full coaching plan view is under development');
  };

  // Handle practicing recommended area
  const handlePracticeArea = () => {
    // Navigate back to practice screen
    navigation.navigate('Practice');
  };

  // Handle navigation
  const handleNavigation = (screen) => {
    if (screen === 'practice') {
      navigation.navigate('Practice');
    } else {
      Alert.alert('Coming Soon', `${screen} screen is under development`);
    }
  };

  // Calculate metric comparisons
  const getMetricComparison = (currentValue, metricType) => {
    if (!previousSession || !previousSession.analysis_json) {
      return null;
    }

    const previousValue = previousSession.analysis_json[metricType];
    if (previousValue === undefined || previousValue === null) {
      return null;
    }

    const delta = ((currentValue - previousValue) / previousValue) * 100;

    // For filler_rate, lower is better
    const isImprovement =
      metricType === 'filler_rate' ? delta < 0 : delta > 0;

    return {
      delta: Math.abs(delta),
      isImprovement,
    };
  };

  // Get letter grade from score
  const getLetterGrade = (score) => {
    const percentage = score * 100;
    if (percentage >= 97) return 'A+';
    if (percentage >= 93) return 'A';
    if (percentage >= 90) return 'A-';
    if (percentage >= 87) return 'B+';
    if (percentage >= 83) return 'B';
    if (percentage >= 80) return 'B-';
    if (percentage >= 77) return 'C+';
    if (percentage >= 73) return 'C';
    if (percentage >= 70) return 'C-';
    return 'D';
  };

  // Get status text for each metric
  const getClarityStatus = (score) => {
    const percentage = score * 100;
    if (percentage >= 85) return 'Very clear';
    if (percentage >= 75) return 'Generally clear';
    return 'Needs improvement';
  };

  const getFillerStatus = (rate) => {
    const percentage = rate * 100;
    if (percentage < 3) return 'Excellent - Professional level';
    if (percentage < 5) return 'Good - Room for improvement';
    return 'Needs work';
  };

  const getPaceStatus = (wpm) => {
    if (wpm >= 140 && wpm <= 180) return 'Natural range';
    if (wpm < 140) return 'A bit slow';
    return 'A bit fast';
  };

  if (loading || !sessionData || !sessionData.analysis_json) {
    return (
      <SafeAreaView style={styles.container} edges={['top', 'bottom']}>
        <AnimatedBackground />
        <View style={styles.loadingContainer}>
          <Text style={styles.loadingText}>Loading report...</Text>
        </View>
      </SafeAreaView>
    );
  }

  const analysis = sessionData.analysis_json;
  const issues = sessionData.issues || [];
  const isFirstSession = !previousSession; // TODO: Check actual session count

  return (
    <SafeAreaView style={styles.container} edges={['top', 'bottom']}>
      <AnimatedBackground />

      <ScrollView
        style={styles.scrollView}
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}
      >
        {/* Session Title */}
        <Text style={styles.sessionTitle}>
          {sessionData.title || `Practice Session #${sessionData.id}`}
        </Text>

        {/* Audio Player */}
        {/* TODO: Implement audio player component */}
        <View style={styles.audioPlayerPlaceholder}>
          <Text style={styles.audioPlayerText}>🎵 Audio Player</Text>
          <Text style={styles.audioPlayerSubtext}>Coming soon</Text>
        </View>

        {/* Metric Scorecards */}
        <View style={styles.metricsRow}>
          <MetricScorecard
            title="Overall Score"
            value={analysis.overall_score}
            displayValue={`${(analysis.overall_score * 100).toFixed(0)}%`}
            grade={getLetterGrade(analysis.overall_score)}
            status="Combined performance"
            comparison={getMetricComparison(analysis.overall_score, 'overall_score')}
            onInfoPress={() => setSelectedMetric('overall')}
          />

          <MetricScorecard
            title="Clarity"
            value={analysis.clarity_score}
            displayValue={`${(analysis.clarity_score * 100).toFixed(0)}%`}
            status={getClarityStatus(analysis.clarity_score)}
            comparison={getMetricComparison(analysis.clarity_score, 'clarity_score')}
            onInfoPress={() => setSelectedMetric('clarity')}
          />

          <MetricScorecard
            title="Filler Words"
            value={analysis.filler_rate}
            displayValue={`${(analysis.filler_rate * 100).toFixed(1)}%`}
            status={getFillerStatus(analysis.filler_rate)}
            comparison={getMetricComparison(analysis.filler_rate, 'filler_rate')}
            onInfoPress={() => setSelectedMetric('filler')}
          />

          <MetricScorecard
            title="Speaking Pace"
            value={analysis.wpm}
            displayValue={`${Math.round(analysis.wpm)} WPM`}
            status={getPaceStatus(analysis.wpm)}
            comparison={getMetricComparison(analysis.wpm, 'wpm')}
          />
        </View>

        {/* Coach Recommendation */}
        <CoachRecommendationCard
          recommendation={coachRecommendation}
          weeklyFocus={weeklyFocus}
          isFirstSession={isFirstSession}
          onViewPlan={handleViewPlan}
          onPractice={handlePracticeArea}
        />

        {/* Issues List Accordion */}
        <AccordionSection
          title="Issues Found"
          subtitle={`${issues.length} total`}
        >
          <IssuesListContent
            issues={issues}
            onTimestampPress={seekToTimestamp}
          />
        </AccordionSection>

        {/* Secondary Metrics Accordion */}
        <AccordionSection
          title="Secondary Metrics"
          subtitle="Additional insights"
        >
          <SecondaryMetricsContent metrics={analysis} />
        </AccordionSection>

        {/* Transcript Accordion */}
        <AccordionSection
          title="Highlighted Transcript"
          subtitle="See what you said"
        >
          <TranscriptContent
            transcript={analysis.transcript}
            issues={issues}
          />
        </AccordionSection>

        {/* Bottom padding for navigation bar */}
        <View style={{ height: 100 }} />
      </ScrollView>

      {/* Bottom Navigation */}
      <BottomNavigation activeScreen="practice" onNavigate={handleNavigation} />

      {/* Metric Info Modal */}
      <MetricInfoModal
        visible={selectedMetric !== null}
        metricType={selectedMetric}
        onClose={() => setSelectedMetric(null)}
      />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background,
  },
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    paddingHorizontal: SPACING.lg,
    paddingTop: SPACING.md,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  loadingText: {
    fontSize: 18,
    color: COLORS.textSecondary,
  },
  sessionTitle: {
    fontSize: 24,
    fontWeight: '700',
    color: COLORS.text,
    marginBottom: SPACING.md,
  },
  audioPlayerPlaceholder: {
    backgroundColor: COLORS.cardBackground,
    borderRadius: 16,
    padding: SPACING.lg,
    alignItems: 'center',
    marginBottom: SPACING.md,
  },
  audioPlayerText: {
    fontSize: 18,
    fontWeight: '600',
    color: COLORS.text,
    marginBottom: 4,
  },
  audioPlayerSubtext: {
    fontSize: 14,
    color: COLORS.textSecondary,
  },
  metricsRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: SPACING.md,
  },
});
