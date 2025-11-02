import React from 'react';
import { View, Text, StyleSheet, Dimensions } from 'react-native';
import { LineChart } from 'react-native-gifted-charts';
import { COLORS, SPACING } from '../constants/colors';

const { width } = Dimensions.get('window');

export default function MetricChartCard({
  title,
  currentValue,
  bestValue,
  trend,
  data,
  unit = '',
  style
}) {
  const getTrendColor = () => {
    if (trend === 'up') return COLORS.success;
    if (trend === 'down') return COLORS.danger;
    return COLORS.textSecondary;
  };

  const getTrendIcon = () => {
    if (trend === 'up') return '↗';
    if (trend === 'down') return '↘';
    return '→';
  };

  // Custom tooltip component
  const CustomTooltip = ({ label, value }) => {
    return (
      <View style={styles.tooltipContainer}>
        <View style={styles.tooltipBubble}>
          <Text style={styles.tooltipLabel}>{label}</Text>
          <Text style={styles.tooltipValue}>
            {value}{unit}
          </Text>
        </View>
      </View>
    );
  };

  // Render chart based on data availability
  const renderChart = () => {
    if (!data || data.length === 0) {
      return (
        <View style={styles.emptyState}>
          <Text style={styles.emptyText}>No data available</Text>
        </View>
      );
    }

    // Special handling for single data point
    if (data.length === 1) {
      return (
        <View style={styles.emptyState}>
          <Text style={styles.singlePointLabel}>{data[0].date}</Text>
          <Text style={styles.singlePointValue}>
            {data[0].value}
            {unit}
          </Text>
          <Text style={styles.singlePointHint}>
            Complete more sessions to see your progress chart
          </Text>
        </View>
      );
    }

    // Transform data for react-native-gifted-charts
    const chartData = data.map((point, index) => ({
      value: point.value || 0,
      label: point.date || `${index + 1}`,
      dataPointText: `${point.value}${unit}`,
      // Store original data for tooltip
      originalLabel: point.date,
      originalValue: point.value,
    }));

    // Calculate value range for better Y-axis scaling
    const values = data.map(d => d.value || 0);
    const maxValue = Math.max(...values);
    const minValue = Math.min(...values);
    const range = maxValue - minValue;
    const yAxisPadding = range * 0.1 || 1;

    // Determine number of X-axis labels to show
    const maxLabelsToShow = 6;
    const labelInterval = Math.ceil(data.length / maxLabelsToShow);

    return (
      <View style={styles.chartWrapper}>
        <LineChart
          data={chartData}
          width={width - 80}
          height={200}

          // Area chart configuration
          areaChart
          curved

          // Gradient styling
          startFillColor={COLORS.primary}
          startOpacity={0.3}
          endFillColor={COLORS.primary}
          endOpacity={0.05}

          // Line styling
          color={COLORS.primary}
          thickness={3}

          // Data points
          hideDataPoints={false}
          dataPointsColor={COLORS.primary}
          dataPointsRadius={4}
          dataPointsHeight={8}
          dataPointsWidth={8}

          // Animation
          isAnimated
          animationDuration={750}
          animateOnDataChange

          // Y-axis configuration
          hideYAxisText={false}
          yAxisColor={COLORS.border}
          yAxisThickness={1}
          yAxisTextStyle={{
            color: COLORS.textSecondary,
            fontSize: 10,
            fontWeight: '500',
          }}
          noOfSections={4}
          maxValue={maxValue + yAxisPadding}
          minValue={Math.max(0, minValue - yAxisPadding)}
          yAxisLabelSuffix={unit === '%' ? '%' : ''}
          formatYLabel={(value) => {
            if (unit === ' WPM') {
              return Math.round(value).toString();
            }
            return Math.round(value).toString();
          }}

          // X-axis configuration
          xAxisColor={COLORS.border}
          xAxisThickness={1}
          xAxisLabelTextStyle={{
            color: COLORS.textSecondary,
            fontSize: 9,
            fontWeight: '500',
          }}
          hideRules
          rulesColor={COLORS.border}
          rulesType="solid"
          initialSpacing={15}
          spacing={(width - 110) / (data.length > 1 ? data.length - 1 : 1)}

          // Show fewer labels on X-axis to prevent crowding
          xAxisIndicesForLabels={chartData
            .map((_, index) => index)
            .filter((_, index) => index % labelInterval === 0 || index === chartData.length - 1)
          }

          // Interactive tooltip configuration
          pointerConfig={{
            pointerStripHeight: 200,
            pointerStripColor: COLORS.border,
            pointerStripWidth: 2,
            strokeDashArray: [4, 4],
            pointerColor: COLORS.primary,
            radius: 6,
            pointerLabelWidth: 100,
            pointerLabelHeight: 70,
            activatePointersOnLongPress: false,
            autoAdjustPointerLabelPosition: true,
            pointerLabelComponent: (items) => {
              if (!items || items.length === 0) return null;
              const item = items[0];
              return (
                <CustomTooltip
                  label={item.originalLabel || item.label}
                  value={item.originalValue !== undefined ? item.originalValue : item.value}
                />
              );
            },
          }}
        />
      </View>
    );
  };

  return (
    <View style={[styles.card, style]}>
      {/* Header */}
      <View style={styles.header}>
        <View>
          <Text style={styles.title}>{title}</Text>
          <View style={styles.valueRow}>
            <Text style={styles.currentValue}>
              {currentValue}{unit}
            </Text>
            <View style={[styles.trendBadge, { backgroundColor: getTrendColor() + '20' }]}>
              <Text style={[styles.trendText, { color: getTrendColor() }]}>
                {getTrendIcon()} {trend}
              </Text>
            </View>
          </View>
        </View>
        {bestValue && (
          <View style={styles.bestValueContainer}>
            <Text style={styles.bestLabel}>Best</Text>
            <Text style={styles.bestValue}>{bestValue}{unit}</Text>
          </View>
        )}
      </View>

      {/* Chart */}
      <View style={styles.chartContainer}>
        {renderChart()}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: COLORS.cardBackground,
    borderRadius: 16,
    borderWidth: 1,
    borderColor: COLORS.border,
    padding: SPACING.md,
    shadowColor: COLORS.text,
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.08,
    shadowRadius: 8,
    elevation: 3,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: SPACING.md,
  },
  title: {
    fontSize: 18,
    fontWeight: '600',
    color: COLORS.text,
    marginBottom: 4,
  },
  valueRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  currentValue: {
    fontSize: 28,
    fontWeight: 'bold',
    color: COLORS.primary,
  },
  trendBadge: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 8,
  },
  trendText: {
    fontSize: 12,
    fontWeight: '600',
  },
  bestValueContainer: {
    alignItems: 'flex-end',
  },
  bestLabel: {
    fontSize: 11,
    fontWeight: '500',
    color: COLORS.textSecondary,
    marginBottom: 2,
  },
  bestValue: {
    fontSize: 16,
    fontWeight: '600',
    color: COLORS.text,
  },
  chartContainer: {
    alignItems: 'center',
  },
  chartWrapper: {
    width: width - 48,
    height: 220,
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 10,
  },
  emptyState: {
    height: 220,
    justifyContent: 'center',
    alignItems: 'center',
  },
  emptyText: {
    fontSize: 14,
    color: COLORS.textSecondary,
  },
  singlePointLabel: {
    fontSize: 12,
    color: COLORS.textSecondary,
    marginBottom: 8,
    fontWeight: '500',
  },
  singlePointValue: {
    fontSize: 36,
    fontWeight: 'bold',
    color: COLORS.primary,
    marginBottom: 12,
  },
  singlePointHint: {
    fontSize: 13,
    color: COLORS.textSecondary,
    textAlign: 'center',
    fontStyle: 'italic',
  },
  tooltipContainer: {
    marginBottom: 10,
  },
  tooltipBubble: {
    backgroundColor: COLORS.cardBackground,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: COLORS.border,
    paddingHorizontal: 12,
    paddingVertical: 8,
    shadowColor: COLORS.text,
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.15,
    shadowRadius: 4,
    elevation: 4,
  },
  tooltipLabel: {
    fontSize: 11,
    color: COLORS.textSecondary,
    fontWeight: '500',
    marginBottom: 2,
  },
  tooltipValue: {
    fontSize: 14,
    color: COLORS.text,
    fontWeight: 'bold',
  },
});
