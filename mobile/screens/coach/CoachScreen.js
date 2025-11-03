import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, ActivityIndicator, RefreshControl } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import AnimatedBackground from '../../components/AnimatedBackground';
import BottomNavigation from '../../components/BottomNavigation';
import DrillCard from '../../components/DrillCard';
import ProgressStatsRow from '../../components/ProgressStatsRow';
import CalendarView from '../../components/CalendarView';
import { COLORS, SPACING, TYPOGRAPHY } from '../../constants/colors';
import { getCoachRecommendations, getSessions } from '../../services/api';

export default function CoachScreen({ navigation }) {
  const userId = 'test-user'; // TODO: Get from auth context

  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [coachData, setCoachData] = useState(null);
  const [weeklyFocus, setWeeklyFocus] = useState(null);
  const [dailyPlan, setDailyPlan] = useState(null);
  const [lastSession, setLastSession] = useState(null);
  const [practiceDates, setPracticeDates] = useState([]);
  const [weeklyTracking, setWeeklyTracking] = useState({
    today_completed: 0,
    today_target: 2,
    week_completed: 0,
    week_target: 10,
    streak: 0,
  });
  const [error, setError] = useState(null);

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      setError(null);
      const [coachRecommendations, sessionsData] = await Promise.all([
        getCoachRecommendations(),
        getSessions({ limit: 100 }),
      ]);

      setCoachData(coachRecommendations);
      setWeeklyFocus(coachRecommendations.weekly_focus || null);
      setDailyPlan(coachRecommendations.daily_plan || null);
      setLastSession(coachRecommendations.last_session_insight || null);
      setWeeklyTracking(coachRecommendations.weekly_focus_tracking || weeklyTracking);

      // Extract practice dates
      const dates = sessionsData
        .filter(session => session.completed)
        .map(session => session.created_at);
      setPracticeDates(dates);
    } catch (err) {
      console.error('Error loading coach data:', err);
      setError(err.message);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  const handleRefresh = () => {
    setRefreshing(true);
    loadData();
  };


  const handleStartDrill = (drill) => {
    // Navigate to Practice screen with pre-filled parameters
    navigation.navigate('Practice', {
      presetDuration: drill.duration_seconds,
      drillTitle: drill.title,
      weeklyFocusId: weeklyFocus?.id,
    });
  };

  const renderLastSessionInsight = () => {
    if (!lastSession || !lastSession.key_metrics) return null;

    const metrics = [
      { label: 'Filler', value: `${Math.round(lastSession.key_metrics.filler_rate.value * 100)}%` },
      { label: 'Clarity', value: `${Math.round(lastSession.key_metrics.clarity_score.value * 100)}%` },
      { label: 'Pace', value: `${Math.round(lastSession.key_metrics.wpm.value)} WPM` },
      { label: 'Fluency', value: `${Math.round(lastSession.key_metrics.fluency_score.value * 100)}%` },
      { label: 'Engage', value: `${Math.round(lastSession.key_metrics.engagement_score.value * 100)}%` },
      { label: 'Consist', value: `${Math.round(lastSession.key_metrics.pace_consistency.value * 100)}%` },
    ];

    return (
      <View style={styles.card}>
        <View style={styles.cardHeader}>
          <Text style={styles.cardTitle}>Last Session Insight</Text>
          <Text style={styles.dateText}>
            {new Date(lastSession.date).toLocaleDateString()}
          </Text>
        </View>

        {/* Overall Score with Delta */}
        <View style={styles.overallScoreContainer}>
          <View>
            <Text style={styles.overallLabel}>Overall Score</Text>
            <Text style={styles.overallScore}>
              {Math.round(lastSession.key_metrics.overall_score.value * 100)}
            </Text>
          </View>
          {lastSession.key_metrics.overall_score.delta !== 0 && (
            <View style={[
              styles.deltaBadge,
              { backgroundColor: lastSession.key_metrics.overall_score.delta > 0 ? COLORS.success + '20' : COLORS.danger + '20' }
            ]}>
              <Text style={[
                styles.deltaText,
                { color: lastSession.key_metrics.overall_score.delta > 0 ? COLORS.success : COLORS.danger }
              ]}>
                {lastSession.key_metrics.overall_score.delta > 0 ? '↗' : '↘'} {Math.abs(Math.round(lastSession.key_metrics.overall_score.delta * 100))}
              </Text>
            </View>
          )}
        </View>

        {/* Metrics Grid (3x2) */}
        <View style={styles.metricsGrid}>
          {metrics.map((metric, index) => (
            <View key={index} style={styles.metricTile}>
              <Text style={styles.metricTileValue}>{metric.value}</Text>
              <Text style={styles.metricTileLabel}>{metric.label}</Text>
            </View>
          ))}
        </View>

        {/* Narrative Summary */}
        {lastSession.narrative && (
          <View style={styles.narrativeContainer}>
            <Text style={styles.narrativeText}>{lastSession.narrative}</Text>
          </View>
        )}

        {/* View Report Button */}
        <TouchableOpacity
          style={styles.viewReportButton}
          onPress={() => navigation.navigate('SessionReport', { sessionId: lastSession.session })}
          activeOpacity={0.7}
        >
          <Text style={styles.viewReportText}>View Full Report</Text>
          <Ionicons name="arrow-forward" size={16} color={COLORS.primary} />
        </TouchableOpacity>
      </View>
    );
  };

  const renderWeeklyFocus = () => {
    if (!weeklyFocus) return null;

    return (
      <View style={styles.card}>
        <View style={styles.cardHeader}>
          <Text style={styles.cardTitle}>Weekly Goal</Text>
          <View style={styles.timeBadge}>
            <Ionicons name="time-outline" size={14} color={COLORS.textSecondary} />
            <Text style={styles.timeText}>{weeklyFocus.time_estimate || '6-8 min/day'}</Text>
          </View>
        </View>

        <Text style={styles.focusTitle}>{weeklyFocus.title}</Text>

        {/* Progress Narrative */}
        {weeklyFocus.narrative && (
          <Text style={styles.focusNarrative}>{weeklyFocus.narrative}</Text>
        )}

        {/* Progress Stats Row */}
        <ProgressStatsRow
          todayCompleted={weeklyTracking.sessions_today}
          todayTarget={weeklyTracking.target_today}
          weekCompleted={weeklyTracking.sessions_this_week}
          weekTarget={weeklyTracking.target_this_week}
          streakDays={weeklyTracking.streak_days}
          style={styles.progressStats}
        />

        {/* Why This Focus */}
        {weeklyFocus.reasoning && (
          <View style={styles.whyFocusContainer}>
            <Text style={styles.whyFocusTitle}>Why this focus?</Text>
            <Text style={styles.whyFocusText}>{weeklyFocus.reasoning}</Text>
          </View>
        )}
      </View>
    );
  };

  const renderDailyPlan = () => {
    if (!dailyPlan?.drills || dailyPlan.drills.length === 0) return null;

    return (
      <View>
        <View style={styles.sectionHeader}>
          <Text style={styles.sectionTitle}>Today's Focus</Text>
          <Text style={styles.sectionSubtitle}>
            {dailyPlan.estimated_time || '6-8 min total'}
          </Text>
        </View>

        {dailyPlan.drills.map((drill, index) => (
          <DrillCard
            key={index}
            order={drill.order || index + 1}
            title={drill.title}
            description={drill.description}
            reasoning={drill.reasoning}
            duration={drill.duration_seconds}
            onStart={() => handleStartDrill(drill)}
          />
        ))}
      </View>
    );
  };

  if (loading) {
    return (
      <SafeAreaView style={styles.container} edges={['top', 'bottom']}>
        <AnimatedBackground />
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="large" color={COLORS.primary} />
          <Text style={styles.loadingText}>Loading your coaching plan...</Text>
        </View>
        <BottomNavigation activeScreen="coach" />
      </SafeAreaView>
    );
  }

  if (error) {
    return (
      <SafeAreaView style={styles.container} edges={['top', 'bottom']}>
        <AnimatedBackground />
        <View style={styles.errorContainer}>
          <Ionicons name="alert-circle-outline" size={48} color={COLORS.danger} />
          <Text style={styles.errorText}>Error loading coach data</Text>
          <Text style={styles.errorSubtext}>{error}</Text>
          <TouchableOpacity style={styles.retryButton} onPress={loadData}>
            <Text style={styles.retryButtonText}>Retry</Text>
          </TouchableOpacity>
        </View>
        <BottomNavigation activeScreen="coach" />
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container} edges={['top', 'bottom']}>
      <AnimatedBackground />

      <ScrollView
        style={styles.content}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={handleRefresh} />
        }
      >
        <Text style={styles.title}>Your Coach</Text>

        {/* Single Column Layout */}
        {/* 1. Last Session Insight */}
        {renderLastSessionInsight()}

        {/* 2. Today's Focus (Daily Plan) */}
        {renderDailyPlan()}

        {/* 3. Weekly Goal */}
        {renderWeeklyFocus()}

        {/* 4. Practice Calendar */}
        <View style={styles.calendarSection}>
          <Text style={styles.sectionTitle}>Practice Calendar</Text>
          <CalendarView practiceDates={practiceDates} />
        </View>

        <View style={{ height: 100 }} />
      </ScrollView>

      <BottomNavigation activeScreen="coach" />
    </SafeAreaView>
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
    paddingTop: SPACING.lg,
    paddingBottom: 100,
  },
  title: {
    ...TYPOGRAPHY.heading,
    color: COLORS.text,
    marginBottom: SPACING.xs,
  },
  card: {
    backgroundColor: COLORS.cardBackground,
    borderRadius: 16,
    borderWidth: 1,
    borderColor: COLORS.border,
    padding: SPACING.md,
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
  cardHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.sm,
  },
  cardTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: COLORS.text,
  },
  dateText: {
    fontSize: 12,
    color: COLORS.textSecondary,
  },
  timeBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    paddingHorizontal: 8,
    paddingVertical: 4,
    backgroundColor: COLORS.background,
    borderRadius: 8,
  },
  timeText: {
    fontSize: 11,
    fontWeight: '600',
    color: COLORS.textSecondary,
  },
  overallScoreContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.md,
  },
  overallLabel: {
    fontSize: 13,
    fontWeight: '600',
    color: COLORS.textSecondary,
    marginBottom: 4,
  },
  overallScore: {
    fontSize: 32,
    fontWeight: 'bold',
    color: COLORS.primary,
  },
  deltaBadge: {
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderRadius: 8,
  },
  deltaText: {
    fontSize: 14,
    fontWeight: '600',
  },
  metricsGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
    marginBottom: SPACING.md,
  },
  metricTile: {
    width: '31%',
    backgroundColor: COLORS.background,
    borderRadius: 10,
    padding: 10,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: COLORS.border,
    minHeight: 60,
  },
  metricTileValue: {
    fontSize: 14,
    fontWeight: 'bold',
    color: COLORS.primary,
    marginBottom: 4,
  },
  metricTileLabel: {
    fontSize: 9,
    fontWeight: '600',
    color: COLORS.textSecondary,
    textAlign: 'center',
  },
  narrativeContainer: {
    backgroundColor: COLORS.selectedBackground,
    padding: SPACING.sm,
    borderRadius: 8,
    marginBottom: SPACING.sm,
  },
  narrativeText: {
    fontSize: 13,
    color: COLORS.text,
    lineHeight: 18,
  },
  viewReportButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
    paddingVertical: 10,
    borderWidth: 1,
    borderColor: COLORS.primary,
    borderRadius: 8,
  },
  viewReportText: {
    fontSize: 14,
    fontWeight: '600',
    color: COLORS.primary,
  },
  focusTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: COLORS.text,
    marginBottom: SPACING.sm,
  },
  focusNarrative: {
    fontSize: 14,
    color: COLORS.textSecondary,
    lineHeight: 20,
    marginBottom: SPACING.md,
  },
  progressStats: {
    marginBottom: SPACING.md,
  },
  whyFocusContainer: {
    backgroundColor: COLORS.selectedBackground,
    padding: SPACING.sm,
    borderRadius: 8,
  },
  whyFocusTitle: {
    fontSize: 12,
    fontWeight: '600',
    color: COLORS.text,
    marginBottom: 4,
  },
  whyFocusText: {
    fontSize: 13,
    color: COLORS.textSecondary,
    lineHeight: 18,
  },
  sectionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.md,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: COLORS.text,
  },
  sectionSubtitle: {
    fontSize: 13,
    color: COLORS.textSecondary,
  },
  calendarSection: {
    marginBottom: SPACING.xl,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  loadingText: {
    marginTop: SPACING.md,
    fontSize: 16,
    color: COLORS.textSecondary,
  },
  errorContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: SPACING.xl,
  },
  errorText: {
    fontSize: 18,
    fontWeight: '600',
    color: COLORS.text,
    marginTop: SPACING.md,
    marginBottom: SPACING.xs,
  },
  errorSubtext: {
    fontSize: 14,
    color: COLORS.textSecondary,
    textAlign: 'center',
    marginBottom: SPACING.xl,
  },
  retryButton: {
    backgroundColor: COLORS.primary,
    paddingHorizontal: SPACING.xl,
    paddingVertical: SPACING.sm,
    borderRadius: 8,
  },
  retryButtonText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '600',
  },
});
