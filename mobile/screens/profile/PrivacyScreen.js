import React, { useState } from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, Linking, Alert, ActivityIndicator } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import AnimatedBackground from '../../components/AnimatedBackground';
import { COLORS, SPACING, TYPOGRAPHY } from '../../constants/colors';
import { useAuth } from '../../context/AuthContext';

export default function PrivacyScreen({ navigation }) {
  const { deleteAccount } = useAuth();
  const [exporting, setExporting] = useState(false);
  const [deleting, setDeleting] = useState(false);

  const handleOpenPrivacyPolicy = () => {
    Linking.openURL('https://aitalkcoach.com/privacy');
  };

  const handleExportData = async () => {
    Alert.alert(
      'Export Your Data',
      'This will download all your practice sessions, progress data, and settings as a JSON file.',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Export',
          onPress: async () => {
            setExporting(true);
            try {
              // TODO: Implement actual export API call
              // const data = await exportUserData(userId);
              // await shareFile(data);

              // Simulate export
              await new Promise(resolve => setTimeout(resolve, 2000));

              Alert.alert(
                'Export Successful',
                'Your data has been prepared. Check your downloads folder.'
              );
            } catch (error) {
              console.error('Error exporting data:', error);
              Alert.alert('Error', 'Failed to export data. Please try again.');
            } finally {
              setExporting(false);
            }
          },
        },
      ]
    );
  };

  const handleDeleteAccount = () => {
    Alert.alert(
      'Delete Account',
      'Are you sure you want to delete your account? This action cannot be undone. All your data, including practice sessions and progress, will be permanently deleted.',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: () => confirmDeleteAccount(),
        },
      ]
    );
  };

  const confirmDeleteAccount = () => {
    Alert.alert(
      'Final Confirmation',
      'This is your last chance to cancel. Are you absolutely sure you want to permanently delete your account?',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'I Understand, Delete',
          style: 'destructive',
          onPress: async () => {
            setDeleting(true);
            try {
              // Call the delete account API
              const result = await deleteAccount();

              if (result.success) {
                Alert.alert(
                  'Account Deleted',
                  'Your account has been permanently deleted.',
                  [
                    {
                      text: 'OK',
                      onPress: () => {
                        // AuthContext already handled logout, just navigate to welcome
                        navigation.reset({
                          index: 0,
                          routes: [{ name: 'Welcome' }],
                        });
                      },
                    },
                  ]
                );
              } else {
                Alert.alert('Error', result.error || 'Failed to delete account. Please try again or contact support.');
              }
            } catch (error) {
              console.error('Error deleting account:', error);
              Alert.alert('Error', 'Failed to delete account. Please try again or contact support.');
            } finally {
              setDeleting(false);
            }
          },
        },
      ]
    );
  };

  return (
    <SafeAreaView style={styles.container} edges={['top', 'bottom']}>
      <AnimatedBackground />

      <View style={styles.header}>
        <TouchableOpacity
          onPress={() => navigation.goBack()}
          style={styles.backButton}
          activeOpacity={0.7}
        >
          <Ionicons name="chevron-back" size={28} color={COLORS.text} />
        </TouchableOpacity>
        <Text style={styles.headerTitle}>Privacy</Text>
        <View style={styles.headerRight} />
      </View>

      <ScrollView style={styles.content}>
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Privacy Policy</Text>
          <Text style={styles.sectionDescription}>
            Read our privacy policy to understand how we collect, use, and protect your data.
          </Text>
          <TouchableOpacity
            style={styles.linkButton}
            onPress={handleOpenPrivacyPolicy}
            activeOpacity={0.7}
          >
            <Text style={styles.linkButtonText}>View Privacy Policy</Text>
            <Ionicons name="open-outline" size={20} color={COLORS.primary} />
          </TouchableOpacity>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Data Management</Text>
          <Text style={styles.sectionDescription}>
            Manage your personal data and exercise your privacy rights.
          </Text>

          <TouchableOpacity
            style={[styles.actionButton, exporting && styles.actionButtonDisabled]}
            onPress={handleExportData}
            activeOpacity={0.7}
            disabled={exporting || deleting}
          >
            <View style={styles.actionButtonContent}>
              {exporting ? (
                <ActivityIndicator color={COLORS.primary} />
              ) : (
                <Ionicons name="download-outline" size={24} color={COLORS.text} />
              )}
              <View style={styles.actionButtonText}>
                <Text style={styles.actionButtonTitle}>
                  {exporting ? 'Exporting...' : 'Export Your Data'}
                </Text>
                <Text style={styles.actionButtonSubtitle}>
                  Download all your practice sessions and progress data
                </Text>
              </View>
            </View>
            {!exporting && <Ionicons name="chevron-forward" size={20} color={COLORS.textSecondary} />}
          </TouchableOpacity>

          <TouchableOpacity
            style={[styles.actionButton, styles.dangerButton, deleting && styles.actionButtonDisabled]}
            onPress={handleDeleteAccount}
            activeOpacity={0.7}
            disabled={exporting || deleting}
          >
            <View style={styles.actionButtonContent}>
              {deleting ? (
                <ActivityIndicator color={COLORS.danger} />
              ) : (
                <Ionicons name="trash-outline" size={24} color={COLORS.danger} />
              )}
              <View style={styles.actionButtonText}>
                <Text style={[styles.actionButtonTitle, styles.dangerText]}>
                  {deleting ? 'Deleting...' : 'Delete Account'}
                </Text>
                <Text style={styles.actionButtonSubtitle}>
                  Permanently delete your account and all data
                </Text>
              </View>
            </View>
            {!deleting && <Ionicons name="chevron-forward" size={20} color={COLORS.textSecondary} />}
          </TouchableOpacity>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Consent Settings</Text>
          <Text style={styles.comingSoon}>Analytics and marketing preferences coming soon...</Text>
        </View>
      </ScrollView>
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
    justifyContent: 'space-between',
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.md,
  },
  backButton: {
    width: 40,
    height: 40,
    alignItems: 'center',
    justifyContent: 'center',
  },
  headerTitle: {
    ...TYPOGRAPHY.subheading,
    color: COLORS.text,
    fontWeight: '600',
  },
  headerRight: {
    width: 40,
  },
  content: {
    flex: 1,
    paddingHorizontal: SPACING.lg,
  },
  section: {
    backgroundColor: COLORS.cardBackground,
    borderRadius: 16,
    padding: SPACING.lg,
    marginBottom: SPACING.lg,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 8,
    elevation: 3,
  },
  sectionTitle: {
    ...TYPOGRAPHY.subheading,
    color: COLORS.text,
    marginBottom: SPACING.xs,
  },
  sectionDescription: {
    ...TYPOGRAPHY.body,
    color: COLORS.textSecondary,
    marginBottom: SPACING.md,
  },
  linkButton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: SPACING.xs,
    paddingVertical: SPACING.xs,
  },
  linkButtonText: {
    ...TYPOGRAPHY.body,
    color: COLORS.primary,
    fontWeight: '600',
  },
  actionButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: SPACING.md,
    backgroundColor: COLORS.background,
    borderRadius: 12,
    marginTop: SPACING.sm,
  },
  actionButtonDisabled: {
    opacity: 0.6,
  },
  actionButtonContent: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: SPACING.md,
    flex: 1,
  },
  actionButtonText: {
    flex: 1,
  },
  actionButtonTitle: {
    ...TYPOGRAPHY.body,
    color: COLORS.text,
    fontWeight: '600',
    marginBottom: 2,
  },
  actionButtonSubtitle: {
    ...TYPOGRAPHY.small,
    color: COLORS.textSecondary,
  },
  dangerButton: {
    borderWidth: 1,
    borderColor: COLORS.danger + '20',
  },
  dangerText: {
    color: COLORS.danger,
  },
  comingSoon: {
    ...TYPOGRAPHY.body,
    color: COLORS.textSecondary,
    fontStyle: 'italic',
  },
});
