import React from 'react';
import { View, Text, StyleSheet, Dimensions } from 'react-native';
import { COLORS, SPACING } from '../constants/colors';

const { width } = Dimensions.get('window');

export default function CalendarView({ practiceDates, style }) {
  // Get current month info
  const today = new Date();
  const currentYear = today.getFullYear();
  const currentMonth = today.getMonth();

  // Get first and last day of month
  const firstDay = new Date(currentYear, currentMonth, 1);
  const lastDay = new Date(currentYear, currentMonth + 1, 0);
  const daysInMonth = lastDay.getDate();
  const startingDayOfWeek = firstDay.getDay();

  // Month name
  const monthNames = ['January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'];

  // Day abbreviations
  const dayAbbreviations = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  // Convert practice dates to set for O(1) lookup
  const practiceDateSet = new Set(
    (practiceDates || []).map(dateStr => {
      const d = new Date(dateStr);
      return `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`;
    })
  );

  // Check if a date has practice
  const hasPractice = (day) => {
    const dateKey = `${currentYear}-${currentMonth}-${day}`;
    return practiceDateSet.has(dateKey);
  };

  // Is today
  const isToday = (day) => {
    return day === today.getDate() &&
           currentMonth === today.getMonth() &&
           currentYear === today.getFullYear();
  };

  // Generate calendar grid
  const calendarDays = [];

  // Empty cells for days before month starts
  for (let i = 0; i < startingDayOfWeek; i++) {
    calendarDays.push(null);
  }

  // Actual days
  for (let day = 1; day <= daysInMonth; day++) {
    calendarDays.push(day);
  }

  // Split into weeks
  const weeks = [];
  for (let i = 0; i < calendarDays.length; i += 7) {
    weeks.push(calendarDays.slice(i, i + 7));
  }

  return (
    <View style={[styles.container, style]}>
      <Text style={styles.monthTitle}>
        {monthNames[currentMonth]} {currentYear}
      </Text>

      {/* Day headers */}
      <View style={styles.weekRow}>
        {dayAbbreviations.map((day, index) => (
          <View key={`header-${index}`} style={styles.dayCell}>
            <Text style={styles.dayHeader}>{day}</Text>
          </View>
        ))}
      </View>

      {/* Calendar grid */}
      {weeks.map((week, weekIndex) => (
        <View key={`week-${weekIndex}`} style={styles.weekRow}>
          {week.map((day, dayIndex) => (
            <View key={`day-${weekIndex}-${dayIndex}`} style={styles.dayCell}>
              {day ? (
                <View style={[
                  styles.dayBox,
                  hasPractice(day) && styles.dayBoxPractice,
                  isToday(day) && styles.dayBoxToday,
                ]}>
                  <Text style={[
                    styles.dayText,
                    hasPractice(day) && styles.dayTextPractice,
                    isToday(day) && styles.dayTextToday,
                  ]}>
                    {day}
                  </Text>
                </View>
              ) : null}
            </View>
          ))}
        </View>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
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
  monthTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: COLORS.text,
    marginBottom: SPACING.sm,
    textAlign: 'center',
  },
  weekRow: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    marginBottom: 4,
  },
  dayCell: {
    width: (width - 80) / 7,
    height: (width - 80) / 7,
    alignItems: 'center',
    justifyContent: 'center',
  },
  dayHeader: {
    fontSize: 11,
    fontWeight: '600',
    color: COLORS.textSecondary,
  },
  dayBox: {
    width: '80%',
    height: '80%',
    borderRadius: 6,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: COLORS.background,
  },
  dayBoxPractice: {
    backgroundColor: COLORS.primary,
  },
  dayBoxToday: {
    borderWidth: 2,
    borderColor: COLORS.primary,
  },
  dayText: {
    fontSize: 12,
    fontWeight: '500',
    color: COLORS.textSecondary,
  },
  dayTextPractice: {
    color: '#FFFFFF',
    fontWeight: '600',
  },
  dayTextToday: {
    color: COLORS.primary,
    fontWeight: '700',
  },
});
