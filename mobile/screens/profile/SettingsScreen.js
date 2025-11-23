import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, ScrollView, TextInput, TouchableOpacity, ActivityIndicator, Alert } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import Slider from '@react-native-community/slider';
import { Ionicons } from '@expo/vector-icons';
import AnimatedBackground from '../../components/AnimatedBackground';
import { COLORS, SPACING, TYPOGRAPHY } from '../../constants/colors';
import { LANGUAGES } from '../../constants/onboardingData';
import { useAuth } from '../../context/AuthContext';
import { updateLanguage, updateTargetWPM } from '../../services/api';

export default function SettingsScreen({ navigation }) {
  const { user, updateUserData } = useAuth();

  const [formData, setFormData] = useState({
    name: user?.name || 'User Name',
    email: user?.email || 'user@example.com',
  });
  const [selectedLanguage, setSelectedLanguage] = useState(user?.preferred_language || 'en');
  const [targetWPM, setTargetWPM] = useState(user?.target_wpm || 140); // Default to 140 WPM
  const [saving, setSaving] = useState(false);
  const [languageUpdating, setLanguageUpdating] = useState(false);
  const [wpmUpdating, setWpmUpdating] = useState(false);

  // Update form data when user changes
  useEffect(() => {
    if (user) {
      setFormData({
        name: user.name,
        email: user.email,
      });
      setSelectedLanguage(user.preferred_language || 'en');
      setTargetWPM(user.target_wpm || 140);
    }
  }, [user]);

  const handleLanguageChange = async (languageCode) => {
    if (languageCode === selectedLanguage) return;

    setLanguageUpdating(true);

    try {
      const response = await updateLanguage(languageCode);
      setSelectedLanguage(languageCode);

      // CRITICAL: Update the AuthContext's cached user object immediately
      // This ensures the app uses the new language for future sessions
      if (updateUserData) {
        updateUserData({
          preferred_language: languageCode,
          language_display_name: response.user?.language_display_name || languageCode
        });
        console.log('Updated cached user language to:', languageCode);
      }

      const languageName = LANGUAGES.find(l => l.id === languageCode)?.label || languageCode;
      Alert.alert(
        'Language Updated',
        `Your preferred language has been changed to ${languageName}. Future recordings will be analyzed in this language.`
      );
    } catch (error) {
      console.error('Error updating language:', error);
      Alert.alert('Error', 'Failed to update language preference. Please try again.');
    } finally {
      setLanguageUpdating(false);
    }
  };

  const handleWPMChange = async (wpm) => {
    const roundedWPM = Math.round(wpm);
    setTargetWPM(roundedWPM);

    // Debounce API calls - only update when user releases slider
    // The actual update happens in handleWPMSave
  };

  const handleWPMSave = async () => {
    setWpmUpdating(true);

    try {
      const response = await updateTargetWPM(targetWPM);

      // Update the AuthContext's cached user object
      if (updateUserData && response.user) {
        updateUserData({
          target_wpm: response.user.target_wpm,
          wpm_settings: response.user.wpm_settings
        });
        console.log('Updated cached user target WPM to:', targetWPM);
      }

      const optimalRange = response.wpm_settings?.optimal_range;
      const rangeText = optimalRange ? `${optimalRange.min}-${optimalRange.max} WPM` : `${targetWPM - 10}-${targetWPM + 10} WPM`;

      Alert.alert(
        'Target Pace Updated',
        `Your target speaking pace has been set to ${targetWPM} WPM.\n\nOptimal range: ${rangeText}\n\nFuture practice sessions will use this custom target.`
      );
    } catch (error) {
      console.error('Error updating target WPM:', error);
      Alert.alert('Error', 'Failed to update target pace. Please try again.');
    } finally {
      setWpmUpdating(false);
    }
  };

  const handleSave = async () => {
    // Validate inputs
    if (!formData.name.trim()) {
      Alert.alert('Validation Error', 'Please enter your name');
      return;
    }

    if (!formData.email.trim() || !formData.email.includes('@')) {
      Alert.alert('Validation Error', 'Please enter a valid email address');
      return;
    }

    setSaving(true);

    try {
      // TODO: Replace with actual API call
      // await updateUser(userId, formData);

      // Simulate API call
      await new Promise(resolve => setTimeout(resolve, 1000));

      Alert.alert(
        'Success',
        'Your settings have been saved successfully',
        [{ text: 'OK', onPress: () => navigation.goBack() }]
      );
    } catch (error) {
      console.error('Error saving settings:', error);
      Alert.alert('Error', 'Failed to save settings. Please try again.');
    } finally {
      setSaving(false);
    }
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
        <Text style={styles.headerTitle}>Settings</Text>
        <View style={styles.headerRight} />
      </View>

      <ScrollView style={styles.content}>
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Account Settings</Text>

          <View style={styles.formGroup}>
            <Text style={styles.label}>Name</Text>
            <TextInput
              style={styles.input}
              value={formData.name}
              onChangeText={(text) => setFormData({ ...formData, name: text })}
              placeholder="Enter your name"
              placeholderTextColor={COLORS.textMuted}
            />
          </View>

          <View style={styles.formGroup}>
            <Text style={styles.label}>Email</Text>
            <TextInput
              style={styles.input}
              value={formData.email}
              onChangeText={(text) => setFormData({ ...formData, email: text })}
              placeholder="Enter your email"
              placeholderTextColor={COLORS.textMuted}
              keyboardType="email-address"
              autoCapitalize="none"
            />
          </View>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Preferences</Text>

          <View style={styles.formGroup}>
            <Text style={styles.label}>Language</Text>
            <Text style={styles.languageHint}>
              Choose the language you'll speak in during practice sessions
            </Text>

            <View style={styles.languageGrid}>
              {LANGUAGES.map((language) => (
                <TouchableOpacity
                  key={language.id}
                  style={[
                    styles.languageOption,
                    selectedLanguage === language.id && styles.languageOptionSelected,
                    languageUpdating && styles.languageOptionDisabled,
                  ]}
                  onPress={() => handleLanguageChange(language.id)}
                  activeOpacity={0.7}
                  disabled={languageUpdating}
                >
                  <Text style={styles.languageIcon}>{language.icon}</Text>
                  <Text
                    style={[
                      styles.languageLabel,
                      selectedLanguage === language.id && styles.languageLabelSelected,
                    ]}
                  >
                    {language.label}
                  </Text>
                  {selectedLanguage === language.id && (
                    <Ionicons
                      name="checkmark-circle"
                      size={20}
                      color={COLORS.primary}
                      style={styles.languageCheck}
                    />
                  )}
                </TouchableOpacity>
              ))}
            </View>

            {languageUpdating && (
              <View style={styles.updatingContainer}>
                <ActivityIndicator color={COLORS.primary} />
                <Text style={styles.updatingText}>Updating language...</Text>
              </View>
            )}
          </View>

          <View style={styles.formGroup}>
            <Text style={styles.label}>Speaking Pace Target</Text>
            <Text style={styles.languageHint}>
              Set your ideal speaking pace. Your optimal range will be ±10 WPM from your target.
            </Text>

            <View style={styles.wpmContainer}>
              <View style={styles.wpmValueContainer}>
                <Text style={styles.wpmValue}>{targetWPM}</Text>
                <Text style={styles.wpmLabel}>WPM</Text>
              </View>

              <Slider
                style={styles.slider}
                minimumValue={60}
                maximumValue={240}
                step={5}
                value={targetWPM}
                onValueChange={handleWPMChange}
                minimumTrackTintColor={COLORS.primary}
                maximumTrackTintColor={COLORS.border}
                thumbTintColor={COLORS.primary}
                disabled={wpmUpdating}
              />

              <View style={styles.wpmRangeLabels}>
                <Text style={styles.wpmRangeLabel}>60 (Slow)</Text>
                <Text style={styles.wpmRangeLabel}>140 (Default)</Text>
                <Text style={styles.wpmRangeLabel}>240 (Fast)</Text>
              </View>

              <View style={styles.wpmInfoBox}>
                <Text style={styles.wpmInfoText}>
                  Your optimal range: {targetWPM - 10}-{targetWPM + 10} WPM
                </Text>
                <Text style={styles.wpmInfoSubtext}>
                  Acceptable range: {targetWPM - 30}-{targetWPM + 30} WPM
                </Text>
              </View>

              <TouchableOpacity
                style={[styles.wpmSaveButton, wpmUpdating && styles.wpmSaveButtonDisabled]}
                onPress={handleWPMSave}
                activeOpacity={0.8}
                disabled={wpmUpdating}
              >
                {wpmUpdating ? (
                  <ActivityIndicator color="#FFFFFF" size="small" />
                ) : (
                  <Text style={styles.wpmSaveButtonText}>Update Target Pace</Text>
                )}
              </TouchableOpacity>
            </View>
          </View>
        </View>

        <TouchableOpacity
          style={[styles.saveButton, saving && styles.saveButtonDisabled]}
          onPress={handleSave}
          activeOpacity={0.8}
          disabled={saving}
        >
          {saving ? (
            <ActivityIndicator color="#FFFFFF" />
          ) : (
            <Text style={styles.saveButtonText}>Save Changes</Text>
          )}
        </TouchableOpacity>
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
    marginBottom: SPACING.md,
  },
  formGroup: {
    marginBottom: SPACING.md,
  },
  label: {
    ...TYPOGRAPHY.body,
    color: COLORS.text,
    marginBottom: SPACING.xs,
    fontWeight: '500',
  },
  input: {
    backgroundColor: COLORS.background,
    borderRadius: 12,
    padding: SPACING.md,
    ...TYPOGRAPHY.body,
    color: COLORS.text,
    borderWidth: 1,
    borderColor: COLORS.border,
  },
  comingSoon: {
    ...TYPOGRAPHY.body,
    color: COLORS.textSecondary,
    fontStyle: 'italic',
  },
  saveButton: {
    backgroundColor: COLORS.primary,
    borderRadius: 12,
    padding: SPACING.md,
    alignItems: 'center',
    marginBottom: SPACING.xl,
    shadowColor: COLORS.primary,
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 4,
  },
  saveButtonDisabled: {
    opacity: 0.6,
  },
  saveButtonText: {
    ...TYPOGRAPHY.body,
    color: '#FFFFFF',
    fontWeight: '600',
  },
  languageHint: {
    ...TYPOGRAPHY.caption,
    color: COLORS.textSecondary,
    marginBottom: SPACING.md,
    fontStyle: 'italic',
  },
  languageGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    marginHorizontal: -SPACING.xs,
  },
  languageOption: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.background,
    borderRadius: 12,
    padding: SPACING.sm,
    margin: SPACING.xs,
    borderWidth: 2,
    borderColor: COLORS.border,
    minWidth: '45%',
  },
  languageOptionSelected: {
    borderColor: COLORS.primary,
    backgroundColor: `${COLORS.primary}15`,
  },
  languageOptionDisabled: {
    opacity: 0.5,
  },
  languageIcon: {
    fontSize: 24,
    marginRight: SPACING.xs,
  },
  languageLabel: {
    ...TYPOGRAPHY.body,
    color: COLORS.text,
    flex: 1,
  },
  languageLabelSelected: {
    color: COLORS.primary,
    fontWeight: '600',
  },
  languageCheck: {
    marginLeft: SPACING.xs,
  },
  updatingContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: SPACING.md,
    padding: SPACING.sm,
  },
  updatingText: {
    ...TYPOGRAPHY.body,
    color: COLORS.textSecondary,
    marginLeft: SPACING.sm,
  },
  wpmContainer: {
    marginTop: SPACING.md,
  },
  wpmValueContainer: {
    flexDirection: 'row',
    alignItems: 'baseline',
    justifyContent: 'center',
    marginBottom: SPACING.md,
  },
  wpmValue: {
    fontSize: 48,
    fontWeight: '700',
    color: COLORS.primary,
  },
  wpmLabel: {
    fontSize: 18,
    fontWeight: '600',
    color: COLORS.textSecondary,
    marginLeft: SPACING.xs,
  },
  slider: {
    width: '100%',
    height: 40,
  },
  wpmRangeLabels: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: SPACING.xs,
    paddingHorizontal: SPACING.xs,
  },
  wpmRangeLabel: {
    ...TYPOGRAPHY.caption,
    color: COLORS.textSecondary,
  },
  wpmInfoBox: {
    backgroundColor: `${COLORS.primary}10`,
    borderRadius: 12,
    padding: SPACING.md,
    marginTop: SPACING.md,
  },
  wpmInfoText: {
    ...TYPOGRAPHY.body,
    color: COLORS.text,
    fontWeight: '600',
    marginBottom: SPACING.xs,
  },
  wpmInfoSubtext: {
    ...TYPOGRAPHY.caption,
    color: COLORS.textSecondary,
  },
  wpmSaveButton: {
    backgroundColor: COLORS.primary,
    borderRadius: 12,
    padding: SPACING.md,
    alignItems: 'center',
    marginTop: SPACING.md,
  },
  wpmSaveButtonDisabled: {
    opacity: 0.5,
  },
  wpmSaveButtonText: {
    ...TYPOGRAPHY.body,
    color: '#FFFFFF',
    fontWeight: '600',
  },
});
