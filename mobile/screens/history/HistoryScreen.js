import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, ScrollView, SectionList, ActivityIndicator, RefreshControl, Alert, TouchableOpacity } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import AnimatedBackground from '../../components/AnimatedBackground';
import SessionListCard from '../../components/SessionListCard';
import StatCard from '../../components/StatCard';
import { COLORS, SPACING, TYPOGRAPHY } from '../../constants/colors';
import { getSessions } from '../../services/api';

export default function HistoryScreen({ navigation }) {
  const userId = 'test-user'; // TODO: Get from auth context

  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [sessions, setSessions] = useState([]);
  const [stats, setStats] = useState({
    total: 0,
    completed: 0,
    thisWeek: 0,
    avgWpm: 0,
  });
  const [error, setError] = useState(null);

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      setError(null);
      const sessionsData = await getSessions(userId, { limit: 100 });
      setSessions(sessionsData);
      calculateStats(sessionsData);
    } catch (err) {
      console.error('Error loading history:', err);
      setError(err.message);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  const calculateStats = (sessionsData) => {
    const total = sessionsData.length;
    const completed = sessionsData.filter(s => s.completed).length;

    // This week
    const now = new Date();
    const weekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    const thisWeek = sessionsData.filter(s => new Date(s.created_at) >= weekAgo).length;

    // Average WPM
    const completedSessions = sessionsData.filter(s => s.completed && s.analysis_data?.pace_wpm);
    const totalWpm = completedSessions.reduce((sum, s) => sum + (s.analysis_data?.pace_wpm || 0), 0);
    const avgWpm = completedSessions.length > 0 ? Math.round(totalWpm / completedSessions.length) : 0;

    setStats({ total, completed, thisWeek, avgWpm });
  };

  const handleRefresh = () => {
    setRefreshing(true);
    loadData();
  };

  const handleViewDetails = (session) => {
    navigation.navigate('SessionReport', { sessionId: session.id });
  };

  const handleDelete = (session) => {
    Alert.alert(
      'Delete Session',
      'Are you sure you want to delete this session? This action cannot be undone.',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: () => deleteSession(session.id),
        },
      ]
    );
  };

  const deleteSession = async (sessionId) => {
    try {
      // TODO: Implement delete API call
      // await deleteSessionApi(sessionId);

      // For now, just remove from local state
      setSessions(sessions.filter(s => s.id !== sessionId));
      calculateStats(sessions.filter(s => s.id !== sessionId));
    } catch (err) {
      console.error('Error deleting session:', err);
      Alert.alert('Error', 'Failed to delete session. Please try again.');
    }
  };

  const groupSessionsByDate = () => {
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const thisMonth = new Date(now.getFullYear(), now.getMonth(), 1);

    const todaySessions = [];
    const thisMonthSessions = [];
    const previousSessions = [];

    sessions.forEach(session => {
      const sessionDate = new Date(session.created_at);
      if (sessionDate >= today) {
        todaySessions.push(session);
      } else if (sessionDate >= thisMonth) {
        thisMonthSessions.push(session);
      } else {
        previousSessions.push(session);
      }
    });

    const sections = [];
    if (todaySessions.length > 0) {
      sections.push({ title: 'Today', data: todaySessions });
    }
    if (thisMonthSessions.length > 0) {
      sections.push({ title: 'This Month', data: thisMonthSessions });
    }
    if (previousSessions.length > 0) {
      sections.push({ title: 'Previous', data: previousSessions });
    }

    return sections;
  };

  if (loading) {
    return (
      <SafeAreaView style={styles.container} edges={['top', 'bottom']}>
        <AnimatedBackground />
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="large" color={COLORS.primary} />
          <Text style={styles.loadingText}>Loading history...</Text>
        </View>
      </SafeAreaView>
    );
  }

  if (error) {
    return (
      <SafeAreaView style={styles.container} edges={['top', 'bottom']}>
        <AnimatedBackground />
        <View style={styles.errorContainer}>
          <Ionicons name="alert-circle-outline" size={48} color={COLORS.danger} />
          <Text style={styles.errorText}>Error loading history</Text>
          <Text style={styles.errorSubtext}>{error}</Text>
          <TouchableOpacity style={styles.retryButton} onPress={loadData}>
            <Text style={styles.retryButtonText}>Retry</Text>
          </TouchableOpacity>
        </View>
      </SafeAreaView>
    );
  }

  const sections = groupSessionsByDate();

  return (
    <SafeAreaView style={styles.container} edges={['top', 'bottom']}>
      <AnimatedBackground />

      <View style={styles.header}>
        <TouchableOpacity
          style={styles.backButton}
          onPress={() => navigation.goBack()}
          activeOpacity={0.7}
        >
          <Ionicons name="arrow-back" size={24} color={COLORS.text} />
        </TouchableOpacity>
        <View style={styles.headerTextContainer}>
          <Text style={styles.title}>Practice History</Text>
          <Text style={styles.subtitle}>Browse all your previous sessions</Text>
        </View>
      </View>

      {/* Stats Overview */}
      <View style={styles.statsRow}>
        <StatCard icon="list-outline" label="Total Sessions" value={stats.total} />
        <StatCard icon="checkmark-circle-outline" label="Completed" value={stats.completed} />
      </View>
      <View style={styles.statsRow}>
        <StatCard icon="calendar-outline" label="This Week" value={stats.thisWeek} />
        <StatCard icon="flash-outline" label="Avg WPM" value={stats.avgWpm} />
      </View>

      {/* Session List */}
      {sections.length === 0 ? (
        <View style={styles.emptyState}>
          <Ionicons name="folder-open-outline" size={64} color={COLORS.textSecondary} />
          <Text style={styles.emptyText}>No sessions yet</Text>
          <Text style={styles.emptySubtext}>Start practicing to see your history here</Text>
          <TouchableOpacity
            style={styles.startButton}
            onPress={() => navigation.navigate('Practice')}
            activeOpacity={0.8}
          >
            <Text style={styles.startButtonText}>Start Practice</Text>
          </TouchableOpacity>
        </View>
      ) : (
        <SectionList
          sections={sections}
          keyExtractor={(item) => item.id.toString()}
          renderItem={({ item }) => (
            <SessionListCard
              session={item}
              onViewDetails={() => handleViewDetails(item)}
              onDelete={() => handleDelete(item)}
            />
          )}
          renderSectionHeader={({ section: { title } }) => (
            <View style={styles.sectionHeader}>
              <Text style={styles.sectionTitle}>{title}</Text>
            </View>
          )}
          style={styles.list}
          contentContainerStyle={styles.listContent}
          refreshControl={
            <RefreshControl refreshing={refreshing} onRefresh={handleRefresh} />
          }
        />
      )}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: SPACING.lg,
    paddingTop: SPACING.md,
    paddingBottom: SPACING.sm,
  },
  backButton: {
    marginRight: SPACING.sm,
  },
  headerTextContainer: {
    flex: 1,
  },
  title: {
    ...TYPOGRAPHY.heading,
    color: COLORS.text,
    marginBottom: 2,
  },
  subtitle: {
    ...TYPOGRAPHY.small,
    color: COLORS.textSecondary,
  },
  statsRow: {
    flexDirection: 'row',
    gap: SPACING.sm,
    paddingHorizontal: SPACING.lg,
    marginBottom: SPACING.sm,
  },
  list: {
    flex: 1,
  },
  listContent: {
    paddingHorizontal: SPACING.lg,
    paddingTop: SPACING.md,
    paddingBottom: SPACING.xl,
  },
  sectionHeader: {
    paddingVertical: SPACING.sm,
    marginBottom: SPACING.xs,
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: COLORS.text,
  },
  emptyState: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: SPACING.xl,
    paddingTop: SPACING.xxl * 2,
  },
  emptyText: {
    fontSize: 18,
    fontWeight: '600',
    color: COLORS.text,
    marginTop: SPACING.md,
    marginBottom: SPACING.xs,
  },
  emptySubtext: {
    fontSize: 14,
    color: COLORS.textSecondary,
    textAlign: 'center',
    marginBottom: SPACING.xl,
  },
  startButton: {
    backgroundColor: COLORS.primary,
    paddingHorizontal: SPACING.xl,
    paddingVertical: SPACING.sm,
    borderRadius: 10,
  },
  startButtonText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '600',
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
