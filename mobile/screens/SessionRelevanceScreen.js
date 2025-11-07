import React, { useState } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ScrollView, ActivityIndicator } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useNavigation, useRoute } from '@react-navigation/native';
import { retakeSession, continueSession } from '../services/api';

export default function SessionRelevanceScreen() {
  const navigation = useNavigation();
  const route = useRoute();
  const { session } = route.params;

  const [loading, setLoading] = useState(false);

  const handleTryAgain = async () => {
    try {
      setLoading(true);
      const response = await retakeSession(session.id);

      // Navigate back to PracticeScreen with retake context
      navigation.replace('Practice', {
        isRetake: true,
        originalTitle: response.title,
        promptText: response.prompt_text,
        targetSeconds: response.target_seconds,
        retakeCount: (response.retake_count || 0) + 1,
        relevanceFeedback: response.relevance_feedback,
      });
    } catch (error) {
      console.error('Error initiating retake:', error);
      alert('Failed to start retake. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const handleKeepResponse = async () => {
    try {
      setLoading(true);
      const response = await continueSession(session.id);

      // Navigate to processing screen to continue analysis
      navigation.replace('SessionProcessing', {
        sessionId: response.session_id,
      });
    } catch (error) {
      console.error('Error continuing session:', error);
      alert('Failed to continue with analysis. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const truncateTranscript = (text, maxLength = 150) => {
    if (!text || text.length <= maxLength) return text;
    return text.substring(0, maxLength) + '...';
  };

  const transcript = session.analysis_data?.transcript || '';
  const relevanceFeedback = session.relevance_feedback || 'Your response may have drifted from the original prompt.';

  return (
    <SafeAreaView style={styles.container} edges={['top']}>
      <ScrollView style={styles.scrollView} contentContainerStyle={styles.content}>
        {/* Header */}
        <View style={styles.header}>
          <Text style={styles.icon}>💬</Text>
          <Text style={styles.title}>Let's Refocus</Text>
        </View>

        {/* Main message */}
        <Text style={styles.message}>
          Your response may have drifted from what was asked.
        </Text>

        {/* Original prompt */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Original prompt:</Text>
          <Text style={styles.promptText}>"{session.title}"</Text>
        </View>

        {/* Feedback */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>We noticed:</Text>
          <Text style={styles.feedbackText}>{relevanceFeedback}</Text>
        </View>

        {/* Transcript preview */}
        {transcript && (
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Your response:</Text>
            <Text style={styles.transcriptText}>"{truncateTranscript(transcript)}"</Text>
          </View>
        )}

        {/* Actions */}
        <View style={styles.actions}>
          <TouchableOpacity
            style={[styles.button, styles.primaryButton]}
            onPress={handleTryAgain}
            disabled={loading}
          >
            {loading ? (
              <ActivityIndicator color="#ffffff" />
            ) : (
              <Text style={styles.primaryButtonText}>Try Again</Text>
            )}
          </TouchableOpacity>

          <TouchableOpacity
            style={[styles.button, styles.secondaryButton]}
            onPress={handleKeepResponse}
            disabled={loading}
          >
            {loading ? (
              <ActivityIndicator color="#4A90E2" />
            ) : (
              <Text style={styles.secondaryButtonText}>Keep This Response</Text>
            )}
          </TouchableOpacity>
        </View>

        {/* Help text */}
        <Text style={styles.helpText}>
          No penalty applied if you choose to try again now.
        </Text>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F5F7FA',
  },
  scrollView: {
    flex: 1,
  },
  content: {
    padding: 24,
  },
  header: {
    alignItems: 'center',
    marginBottom: 24,
  },
  icon: {
    fontSize: 48,
    marginBottom: 12,
  },
  title: {
    fontSize: 28,
    fontWeight: '700',
    color: '#1A1A1A',
  },
  message: {
    fontSize: 16,
    color: '#4A4A4A',
    textAlign: 'center',
    marginBottom: 32,
    lineHeight: 24,
  },
  section: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    padding: 16,
    marginBottom: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.05,
    shadowRadius: 4,
    elevation: 2,
  },
  sectionTitle: {
    fontSize: 14,
    fontWeight: '600',
    color: '#7A7A7A',
    marginBottom: 8,
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
  promptText: {
    fontSize: 18,
    fontWeight: '600',
    color: '#1A1A1A',
    lineHeight: 26,
  },
  feedbackText: {
    fontSize: 16,
    color: '#E67E22',
    lineHeight: 24,
    fontWeight: '500',
  },
  transcriptText: {
    fontSize: 15,
    color: '#4A4A4A',
    lineHeight: 22,
    fontStyle: 'italic',
  },
  actions: {
    marginTop: 32,
    marginBottom: 16,
  },
  button: {
    paddingVertical: 16,
    paddingHorizontal: 24,
    borderRadius: 12,
    alignItems: 'center',
    marginBottom: 12,
  },
  primaryButton: {
    backgroundColor: '#4A90E2',
    shadowColor: '#4A90E2',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 4,
  },
  primaryButtonText: {
    color: '#FFFFFF',
    fontSize: 18,
    fontWeight: '700',
  },
  secondaryButton: {
    backgroundColor: '#FFFFFF',
    borderWidth: 2,
    borderColor: '#4A90E2',
  },
  secondaryButtonText: {
    color: '#4A90E2',
    fontSize: 16,
    fontWeight: '600',
  },
  helpText: {
    fontSize: 14,
    color: '#7A7A7A',
    textAlign: 'center',
    fontStyle: 'italic',
    marginTop: 8,
  },
});
