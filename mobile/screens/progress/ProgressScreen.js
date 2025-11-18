import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, ActivityIndicator, RefreshControl, Modal } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import AnimatedBackground from '../../components/AnimatedBackground';
import BottomNavigation from '../../components/BottomNavigation';
import MetricChartCard from '../../components/MetricChartCard';
import TimeRangeSelector from '../../components/TimeRangeSelector';
import CalendarView from '../../components/CalendarView';
import { COLORS, SPACING, TYPOGRAPHY } from '../../constants/colors';
import { getProgressMetrics, getSessions } from '../../services/api';
import { useHaptics } from '../../hooks/useHaptics';

const METRIC_CONFIG = {
  overall: { label: 'Overall', unit: '', key: 'overall_score', chartKey: 'overall_score_data', isPercentage: true },
  filler: { label: 'Filler Rate', unit: '%', key: 'filler_rate', chartKey: 'filler_data', isPercentage: true },
  pace: { label: 'Pace', unit: ' WPM', key: 'wpm', chartKey: 'pace_data', isPercentage: false },
  clarity: { label: 'Clarity', unit: '%', key: 'clarity_score', chartKey: 'clarity_data', isPercentage: true },
  fluency: { label: 'Fluency', unit: '%', key: 'fluency_score', chartKey: 'fluency_data', isPercentage: true },
  engagement: { label: 'Engagement', unit: '%', key: 'engagement_score', chartKey: 'engagement_data', isPercentage: true },
  consistency: { label: 'Consistency', unit: '%', key: 'pace_consistency', chartKey: 'pace_consistency_data', isPercentage: true },
};

export default function ProgressScreen({ navigation }) {
  const userId = 'test-user'; // TODO: Get from auth context
  const haptics = useHaptics();

  const [selectedMetric, setSelectedMetric] = useState('overall');
  const [timeRange, setTimeRange] = useState('10_sessions');
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [progressData, setProgressData] = useState(null);
  const [practiceDates, setPracticeDates] = useState([]);
  const [error, setError] = useState(null);
  const [showDatePicker, setShowDatePicker] = useState(false);
  const [customStartDate, setCustomStartDate] = useState('');
  const [customEndDate, setCustomEndDate] = useState('');

  const timeRangeOptions = [
    { label: '10 Sessions', value: '10_sessions' },
    { label: '10 Days', value: '10' },
    { label: 'Custom', value: 'custom' },
  ];

  useEffect(() => {
    if (timeRange !== 'custom') {
      loadData();
    }
  }, [timeRange, customStartDate, customEndDate]);

  const handleTimeRangeSelect = (value) => {
    if (value === 'custom') {
      setShowDatePicker(true);
    } else {
      setTimeRange(value);
    }
  };

  const handleCustomDateApply = () => {
    if (customStartDate && customEndDate) {
      setTimeRange('custom');
      setShowDatePicker(false);
      loadData();
    }
  };

  const loadData = async () => {
    try {
      setError(null);
      let rangeParam = timeRange;

      // If custom range, send start and end dates
      if (timeRange === 'custom' && customStartDate && customEndDate) {
        rangeParam = `custom:${customStartDate}:${customEndDate}`;
      }

      const [metricsData, sessionsData] = await Promise.all([
        getProgressMetrics(rangeParam),
        getSessions({ limit: 100 }),
      ]);

      setProgressData(metricsData);

      // Extract practice dates from sessions
      const dates = sessionsData
        .filter(session => session.completed)
        .map(session => session.created_at);
      setPracticeDates(dates);
    } catch (err) {
      console.error('Error loading progress data:', err);
      setError(err.message);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  const handleRefresh = () => {
    haptics.light();
    setRefreshing(true);
    loadData();
  };


  const getChartData = () => {
    if (!progressData?.chart_data) return [];

    const chartKey = METRIC_CONFIG[selectedMetric]?.chartKey;
    const chartDataArray = progressData.chart_data[chartKey] || [];

    // Backend returns simple arrays of numbers, not objects with value/date
    // Map them to the format expected by the chart component
    return chartDataArray.map((value, index) => ({
      value: value,
      date: progressData.chart_data.labels?.[index] || `Session ${index + 1}`,
    }));
  };

  const getCurrentValue = () => {
    if (!progressData?.average_values) return '--';
    const config = METRIC_CONFIG[selectedMetric];
    const value = progressData.average_values[config?.key];
    if (value === undefined || value === null) return '--';

    // Convert decimal to percentage if needed
    if (config.isPercentage) {
      return Math.round(value * 100);
    }
    return Math.round(value);
  };

  const getBestValue = () => {
    if (!progressData?.best_values) return null;
    const config = METRIC_CONFIG[selectedMetric];
    const value = progressData.best_values[config?.key];
    if (value === undefined || value === null) return null;

    // Convert decimal to percentage if needed
    if (config.isPercentage) {
      return Math.round(value * 100);
    }
    return Math.round(value);
  };

  const getTrend = () => {
    if (!progressData?.trends) return 'neutral';
    const metricKey = METRIC_CONFIG[selectedMetric]?.key;
    return progressData.trends[metricKey] || 'neutral';
  };

  const getStatsCardValue = (metric) => {
    if (!progressData?.average_values) return '--';
    const config = METRIC_CONFIG[metric];
    const value = progressData.average_values[config?.key];
    if (value === undefined || value === null) return '--';

    // Convert decimal to percentage if needed
    if (config.isPercentage) {
      return Math.round(value * 100);
    }
    return Math.round(value);
  };

  const getStatsDelta = (metric) => {
    if (!progressData?.deltas) return null;
    const config = METRIC_CONFIG[metric];
    const delta = progressData.deltas[config?.key];
    if (delta === undefined || delta === null) return null;

    // Convert decimal delta to percentage if needed
    if (config.isPercentage) {
      return Math.round(delta * 100);
    }
    return Math.round(delta);
  };

  const renderMetricSelector = () => {
    const otherMetrics = ['filler', 'pace', 'clarity', 'fluency', 'engagement', 'consistency'];

    const overallValue = getStatsCardValue('overall');
    const overallDelta = getStatsDelta('overall');
    const overallConfig = METRIC_CONFIG['overall'];
    const isOverallSelected = selectedMetric === 'overall';

    return (
      <View style={styles.metricSelectorContainer}>
        <Text style={styles.sectionTitle}>Select Metric</Text>

        {/* Overall Score Card - Horizontal */}
        <TouchableOpacity
          style={[
            styles.overallCard,
            isOverallSelected && styles.overallCardSelected,
          ]}
          onPress={() => setSelectedMetric('overall')}
          activeOpacity={0.7}
        >
          <View style={styles.overallCardContent}>
            <View>
              <Text style={styles.overallLabel}>Overall Score</Text>
              <Text style={styles.overallValue}>{overallValue}</Text>
            </View>
            {overallDelta !== null && overallDelta !== 0 && (
              <View style={[
                styles.overallDeltaBadge,
                { backgroundColor: overallDelta > 0 ? COLORS.success + '20' : COLORS.danger + '20' }
              ]}>
                <Text style={[
                  styles.overallDeltaText,
                  { color: overallDelta > 0 ? COLORS.success : COLORS.danger }
                ]}>
                  {overallDelta > 0 ? '↗' : '↘'} {Math.abs(overallDelta)}
                </Text>
              </View>
            )}
          </View>
        </TouchableOpacity>

        {/* Other Metrics Grid - 3x2 */}
        <View style={styles.metricsGrid}>
          {otherMetrics.map(metric => {
            const config = METRIC_CONFIG[metric];
            const isSelected = selectedMetric === metric;
            const value = getStatsCardValue(metric);
            const delta = getStatsDelta(metric);

            return (
              <TouchableOpacity
                key={metric}
                style={[
                  styles.metricTile,
                  isSelected && styles.metricTileSelected,
                ]}
                onPress={() => setSelectedMetric(metric)}
                activeOpacity={0.7}
              >
                <Text style={styles.metricTileValue}>
                  {value}{config.unit}
                </Text>
                <Text style={styles.metricTileLabel}>{config.label}</Text>
                {delta !== null && delta !== 0 && (
                  <Text style={[
                    styles.metricTileDelta,
                    { color: delta > 0 ? COLORS.success : COLORS.danger }
                  ]}>
                    {delta > 0 ? '↗' : '↘'} {Math.abs(delta)}
                  </Text>
                )}
              </TouchableOpacity>
            );
          })}
        </View>
      </View>
    );
  };

  if (loading) {
    return (
      <SafeAreaView style={styles.container} edges={['top', 'bottom']}>
        <AnimatedBackground />
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="large" color={COLORS.primary} />
          <Text style={styles.loadingText}>Loading your progress...</Text>
        </View>
        <BottomNavigation activeScreen="progress" />
      </SafeAreaView>
    );
  }

  if (error) {
    return (
      <SafeAreaView style={styles.container} edges={['top', 'bottom']}>
        <AnimatedBackground />
        <View style={styles.errorContainer}>
          <Ionicons name="alert-circle-outline" size={48} color={COLORS.danger} />
          <Text style={styles.errorText}>Error loading progress</Text>
          <Text style={styles.errorSubtext}>{error}</Text>
          <TouchableOpacity style={styles.retryButton} onPress={loadData}>
            <Text style={styles.retryButtonText}>Retry</Text>
          </TouchableOpacity>
        </View>
        <BottomNavigation activeScreen="progress" />
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
        <Text style={styles.title}>Your Progress</Text>

        {/* Time Range Selector */}
        <TimeRangeSelector
          selected={timeRange}
          onSelect={handleTimeRangeSelect}
          options={timeRangeOptions}
          style={styles.timeRangeSelector}
        />

        {/* Custom Date Range Picker Modal */}
        <Modal
          visible={showDatePicker}
          transparent={true}
          animationType="fade"
          onRequestClose={() => setShowDatePicker(false)}
        >
          <TouchableOpacity
            style={styles.modalOverlay}
            activeOpacity={1}
            onPress={() => setShowDatePicker(false)}
          >
            <TouchableOpacity
              style={styles.modalContent}
              activeOpacity={1}
              onPress={(e) => e.stopPropagation()}
            >
              <Text style={styles.modalTitle}>Select Custom Date Range</Text>

              <View style={styles.dateInputContainer}>
                <Text style={styles.dateLabel}>Start Date</Text>
                <TouchableOpacity
                  style={styles.dateInput}
                  onPress={() => {
                    // Simple date input - can be enhanced with actual date picker
                    const today = new Date();
                    const thirtyDaysAgo = new Date(today.setDate(today.getDate() - 30));
                    setCustomStartDate(thirtyDaysAgo.toISOString().split('T')[0]);
                  }}
                >
                  <Text style={styles.dateInputText}>
                    {customStartDate || 'YYYY-MM-DD'}
                  </Text>
                </TouchableOpacity>
              </View>

              <View style={styles.dateInputContainer}>
                <Text style={styles.dateLabel}>End Date</Text>
                <TouchableOpacity
                  style={styles.dateInput}
                  onPress={() => {
                    const today = new Date();
                    setCustomEndDate(today.toISOString().split('T')[0]);
                  }}
                >
                  <Text style={styles.dateInputText}>
                    {customEndDate || 'YYYY-MM-DD'}
                  </Text>
                </TouchableOpacity>
              </View>

              <Text style={styles.dateHint}>Tap the date fields to set to default dates. You can edit the backend to support full date picker functionality.</Text>

              <View style={styles.modalButtons}>
                <TouchableOpacity
                  style={[styles.modalButton, styles.modalButtonSecondary]}
                  onPress={() => {
                    setShowDatePicker(false);
                    setCustomStartDate('');
                    setCustomEndDate('');
                  }}
                >
                  <Text style={styles.modalButtonTextSecondary}>Cancel</Text>
                </TouchableOpacity>
                <TouchableOpacity
                  style={[styles.modalButton, styles.modalButtonPrimary]}
                  onPress={handleCustomDateApply}
                >
                  <Text style={styles.modalButtonTextPrimary}>Apply</Text>
                </TouchableOpacity>
              </View>
            </TouchableOpacity>
          </TouchableOpacity>
        </Modal>

        {/* Metric Selector Cards */}
        {renderMetricSelector()}

        {/* Chart */}
        <MetricChartCard
          title={METRIC_CONFIG[selectedMetric].label}
          currentValue={getCurrentValue()}
          bestValue={getBestValue()}
          trend={getTrend()}
          data={getChartData()}
          unit={METRIC_CONFIG[selectedMetric].unit}
          style={styles.chartCard}
        />

        {/* Practice Calendar */}
        <View style={styles.calendarSection}>
          <Text style={styles.sectionTitle}>Practice Calendar</Text>
          <CalendarView practiceDates={practiceDates} />
        </View>

        <View style={{ height: 100 }} />
      </ScrollView>

      <BottomNavigation activeScreen="progress" />
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
    marginBottom: SPACING.xl,
    fontSize: 32,
    fontWeight: '700',
  },
  timeRangeSelector: {
    marginBottom: SPACING.xl,
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: COLORS.text,
    marginBottom: SPACING.xs,
  },
  metricSelectorContainer: {
    marginBottom: SPACING.md,
  },
  overallCard: {
    backgroundColor: COLORS.cardBackground,
    borderRadius: 16,
    borderWidth: 1,
    borderColor: COLORS.border,
    padding: SPACING.sm,
    paddingVertical: SPACING.sm,
    marginBottom: SPACING.sm,
    shadowColor: COLORS.text,
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.08,
    shadowRadius: 8,
    elevation: 3,
  },
  overallCardSelected: {
    borderColor: COLORS.primary,
    borderWidth: 2,
    backgroundColor: COLORS.selectedBackground,
  },
  overallCardContent: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  overallLabel: {
    fontSize: 12,
    fontWeight: '600',
    color: COLORS.textSecondary,
    marginBottom: 2,
  },
  overallValue: {
    fontSize: 28,
    fontWeight: 'bold',
    color: COLORS.primary,
  },
  overallDeltaBadge: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 6,
  },
  overallDeltaText: {
    fontSize: 12,
    fontWeight: '600',
  },
  metricsGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 6,
  },
  metricTile: {
    width: '31.5%',
    backgroundColor: COLORS.cardBackground,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: COLORS.border,
    padding: 8,
    alignItems: 'center',
    justifyContent: 'center',
    minHeight: 65,
    shadowColor: COLORS.text,
    shadowOffset: {
      width: 0,
      height: 1,
    },
    shadowOpacity: 0.05,
    shadowRadius: 3,
    elevation: 2,
  },
  metricTileSelected: {
    borderColor: COLORS.primary,
    borderWidth: 2,
    backgroundColor: COLORS.selectedBackground,
  },
  metricTileValue: {
    fontSize: 14,
    fontWeight: 'bold',
    color: COLORS.primary,
    marginBottom: 2,
  },
  metricTileLabel: {
    fontSize: 9,
    fontWeight: '600',
    color: COLORS.text,
    textAlign: 'center',
  },
  metricTileDelta: {
    fontSize: 8,
    fontWeight: '600',
    marginTop: 1,
  },
  chartCard: {
    marginBottom: SPACING.xl,
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
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'center',
    alignItems: 'center',
    padding: SPACING.xl,
  },
  modalContent: {
    backgroundColor: COLORS.cardBackground,
    borderRadius: 16,
    padding: SPACING.xl,
    width: '100%',
    maxWidth: 400,
    shadowColor: COLORS.text,
    shadowOffset: {
      width: 0,
      height: 4,
    },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 8,
  },
  modalTitle: {
    fontSize: 20,
    fontWeight: '700',
    color: COLORS.text,
    marginBottom: SPACING.lg,
    textAlign: 'center',
  },
  dateInputContainer: {
    marginBottom: SPACING.md,
  },
  dateLabel: {
    fontSize: 14,
    fontWeight: '600',
    color: COLORS.text,
    marginBottom: SPACING.xs,
  },
  dateInput: {
    backgroundColor: COLORS.background,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: COLORS.border,
    padding: SPACING.md,
  },
  dateInputText: {
    fontSize: 16,
    color: COLORS.text,
  },
  dateHint: {
    fontSize: 12,
    color: COLORS.textSecondary,
    marginBottom: SPACING.lg,
    textAlign: 'center',
    fontStyle: 'italic',
  },
  modalButtons: {
    flexDirection: 'row',
    gap: SPACING.sm,
  },
  modalButton: {
    flex: 1,
    paddingVertical: SPACING.md,
    borderRadius: 8,
    alignItems: 'center',
  },
  modalButtonSecondary: {
    backgroundColor: COLORS.background,
    borderWidth: 1,
    borderColor: COLORS.border,
  },
  modalButtonPrimary: {
    backgroundColor: COLORS.primary,
  },
  modalButtonTextSecondary: {
    fontSize: 16,
    fontWeight: '600',
    color: COLORS.text,
  },
  modalButtonTextPrimary: {
    fontSize: 16,
    fontWeight: '600',
    color: '#FFFFFF',
  },
});
