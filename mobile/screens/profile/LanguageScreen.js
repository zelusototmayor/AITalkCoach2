import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, Alert, ActivityIndicator } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import AnimatedBackground from '../../components/AnimatedBackground';
import { COLORS, SPACING, TYPOGRAPHY } from '../../constants/colors';
import { LANGUAGES } from '../../constants/onboardingData';
import { useAuth } from '../../context/AuthContext';
import { updateLanguage } from '../../services/api';

export default function LanguageScreen({ navigation }) {
  const { user, updateUserData } = useAuth();

  const [selectedLanguage, setSelectedLanguage] = useState(user?.preferred_language || 'en');
  const [languageUpdating, setLanguageUpdating] = useState(false);

  // Update selected language when user changes
  useEffect(() => {
    if (user) {
      setSelectedLanguage(user.preferred_language || 'en');
    }
  }, [user]);

  const handleLanguageChange = async (languageCode) => {
    if (languageCode === selectedLanguage) return;

    setLanguageUpdating(true);

    try {
      const response = await updateLanguage(languageCode);
      setSelectedLanguage(languageCode);

      // Update the AuthContext's cached user object immediately
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
        <Text style={styles.headerTitle}>Language</Text>
        <View style={styles.headerRight} />
      </View>

      <ScrollView style={styles.content}>
        <View style={styles.languageSection}>
          <Text style={styles.languageSectionTitle}>Select Your Language</Text>
          <Text style={styles.languageSectionHint}>
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
    paddingTop: SPACING.lg,
  },
  languageSection: {
    backgroundColor: COLORS.cardBackground,
    borderRadius: 16,
    padding: SPACING.lg,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 8,
    elevation: 3,
  },
  languageSectionTitle: {
    ...TYPOGRAPHY.subheading,
    color: COLORS.text,
    fontWeight: '600',
    marginBottom: SPACING.xs,
  },
  languageSectionHint: {
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
});
