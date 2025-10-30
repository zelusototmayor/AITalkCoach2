import React, { useState } from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity } from 'react-native';
import Button from '../../components/Button';
import SelectionButton from '../../components/SelectionButton';
import PillButton from '../../components/PillButton';
import { COLORS, SPACING } from '../../constants/colors';
import { COMMUNICATION_STYLES, AGE_RANGES, LANGUAGES } from '../../constants/onboardingData';
import { useOnboarding } from '../../context/OnboardingContext';

export default function ProfileScreen({ navigation }) {
  const { onboardingData, updateOnboardingData } = useOnboarding();

  const [communicationStyle, setCommunicationStyle] = useState(
    onboardingData.communicationStyle || null
  );
  const [ageRange, setAgeRange] = useState(onboardingData.ageRange || null);
  const [language, setLanguage] = useState(onboardingData.language || 'English');
  const [showLanguageDropdown, setShowLanguageDropdown] = useState(false);

  const handleCommunicationStyleSelect = (styleId) => {
    setCommunicationStyle(styleId);
  };

  const handleAgeRangeSelect = (rangeId) => {
    setAgeRange(rangeId);
  };

  const handleLanguageSelect = (langId) => {
    setLanguage(langId);
    setShowLanguageDropdown(false);
  };

  const handleContinue = () => {
    updateOnboardingData({
      communicationStyle,
      ageRange,
      language,
    });
    navigation.navigate('TrialRecording');
  };

  const isFormValid = communicationStyle && ageRange && language;

  const selectedLanguage = LANGUAGES.find(lang => lang.id === language);

  return (
    <View style={styles.container}>
      <ScrollView
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}
      >
        <Text style={styles.header}>Tell us about yourself</Text>

        {/* Communication Style Section */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Communication Style</Text>
          <View style={styles.gridContainer}>
            {COMMUNICATION_STYLES.map((style) => (
              <SelectionButton
                key={style.id}
                icon={style.icon}
                title={style.title}
                isSelected={communicationStyle === style.id}
                onPress={() => handleCommunicationStyleSelect(style.id)}
              />
            ))}
          </View>
        </View>

        {/* Age Range Section */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Age Range</Text>
          <View style={styles.pillContainer}>
            {AGE_RANGES.map((range) => (
              <PillButton
                key={range.id}
                label={range.label}
                isSelected={ageRange === range.id}
                onPress={() => handleAgeRangeSelect(range.id)}
              />
            ))}
          </View>
        </View>

        {/* Language Section */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Language</Text>
          <TouchableOpacity
            style={styles.languageSelector}
            onPress={() => setShowLanguageDropdown(!showLanguageDropdown)}
          >
            <Text style={styles.languageText}>
              {selectedLanguage ? `${selectedLanguage.icon} ${selectedLanguage.label}` : 'Select language'}
            </Text>
            <Text style={styles.dropdownIcon}>{showLanguageDropdown ? '▲' : '▼'}</Text>
          </TouchableOpacity>

          {showLanguageDropdown && (
            <View style={styles.languageDropdown}>
              {LANGUAGES.map((lang) => (
                <TouchableOpacity
                  key={lang.id}
                  style={[
                    styles.languageOption,
                    language === lang.id && styles.languageOptionSelected
                  ]}
                  onPress={() => handleLanguageSelect(lang.id)}
                >
                  <Text style={styles.languageOptionText}>
                    {lang.icon} {lang.label}
                  </Text>
                  {language === lang.id && (
                    <Text style={styles.checkmark}>✓</Text>
                  )}
                </TouchableOpacity>
              ))}
            </View>
          )}
        </View>

        {/* Pagination dots */}
        <View style={styles.paginationContainer}>
          {[...Array(9)].map((_, index) => (
            <View
              key={index}
              style={[
                styles.dot,
                index === 4 && styles.activeDot, // Screen 5 is active (index 4)
              ]}
            />
          ))}
        </View>
      </ScrollView>

      <View style={styles.buttonContainer}>
        <Button
          title="Continue →"
          onPress={handleContinue}
          variant="primary"
          disabled={!isFormValid}
          style={styles.button}
        />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background,
  },
  scrollContent: {
    flexGrow: 1,
    paddingHorizontal: SPACING.lg,
    paddingTop: 60,
    paddingBottom: 120,
  },
  header: {
    fontSize: 28,
    fontWeight: 'bold',
    color: COLORS.text,
    textAlign: 'center',
    marginBottom: SPACING.xxl,
    lineHeight: 36,
  },
  section: {
    marginBottom: SPACING.xl,
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: COLORS.text,
    marginBottom: SPACING.md,
  },
  gridContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
  },
  pillContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
  },
  languageSelector: {
    backgroundColor: COLORS.cardBackground,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: COLORS.border,
    paddingVertical: SPACING.md,
    paddingHorizontal: SPACING.lg,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  languageText: {
    fontSize: 16,
    fontWeight: '500',
    color: COLORS.text,
  },
  dropdownIcon: {
    fontSize: 12,
    color: COLORS.textSecondary,
  },
  languageDropdown: {
    backgroundColor: COLORS.cardBackground,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: COLORS.border,
    marginTop: SPACING.sm,
    overflow: 'hidden',
  },
  languageOption: {
    paddingVertical: SPACING.md,
    paddingHorizontal: SPACING.lg,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border,
  },
  languageOptionSelected: {
    backgroundColor: COLORS.selectedBackground,
  },
  languageOptionText: {
    fontSize: 16,
    fontWeight: '500',
    color: COLORS.text,
  },
  checkmark: {
    fontSize: 18,
    fontWeight: 'bold',
    color: COLORS.primary,
  },
  paginationContainer: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    marginTop: SPACING.xxl,
    gap: SPACING.xs,
  },
  dot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: COLORS.border,
  },
  activeDot: {
    backgroundColor: COLORS.primary,
    width: 10,
    height: 10,
    borderRadius: 5,
  },
  buttonContainer: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    padding: SPACING.lg,
    backgroundColor: COLORS.background,
    borderTopWidth: 1,
    borderTopColor: COLORS.border,
  },
  button: {
    width: '100%',
  },
});
