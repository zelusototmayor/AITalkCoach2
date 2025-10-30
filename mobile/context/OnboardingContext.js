import React, { createContext, useContext, useState } from 'react';

const OnboardingContext = createContext();

export const useOnboarding = () => {
  const context = useContext(OnboardingContext);
  if (!context) {
    throw new Error('useOnboarding must be used within OnboardingProvider');
  }
  return context;
};

export const OnboardingProvider = ({ children }) => {
  const [onboardingData, setOnboardingData] = useState({
    goals: [],                    // Array of selected goal IDs
    communicationStyle: null,     // "introvert" | "extrovert" | "ambivert" | "not_sure"
    ageRange: null,              // "18-24" | "25-34" | "35-44" | "45-54" | "55+"
    language: 'English',         // Default language
    trialSessionToken: null,     // Token from trial recording
    trialResults: null,          // Results from trial session
    selectedPlan: null,          // "monthly" | "yearly"
  });

  const updateOnboardingData = (updates) => {
    setOnboardingData((prev) => ({
      ...prev,
      ...updates,
    }));
  };

  return (
    <OnboardingContext.Provider
      value={{
        onboardingData,
        updateOnboardingData,
      }}
    >
      {children}
    </OnboardingContext.Provider>
  );
};
