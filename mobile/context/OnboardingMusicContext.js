import React, { createContext, useContext, useEffect, useRef } from 'react';
import { Audio } from 'expo-av';

const OnboardingMusicContext = createContext({
  pause: () => {},
  resume: () => {},
});

export function OnboardingMusicProvider({ children }) {
  const soundRef = useRef(null);
  const isLoadedRef = useRef(false);

  useEffect(() => {
    let isMounted = true;

    const loadAndPlayMusic = async () => {
      try {
        // Set audio mode to play in background and mix with other audio
        await Audio.setAudioModeAsync({
          playsInSilentModeIOS: true,
          staysActiveInBackground: false,
          shouldDuckAndroid: true,
        });

        // Load the audio file
        const { sound } = await Audio.Sound.createAsync(
          require('../assets/onboarding-music.mp3'),
          {
            isLooping: true,
            volume: 0.3, // 30% volume for subtle background music
          }
        );

        if (isMounted) {
          soundRef.current = sound;
          isLoadedRef.current = true;

          // Play the music
          await sound.playAsync();
        } else {
          // Component unmounted during loading, clean up
          await sound.unloadAsync();
        }
      } catch (error) {
        console.error('Error loading onboarding music:', error);
      }
    };

    loadAndPlayMusic();

    // Cleanup function
    return () => {
      isMounted = false;
      if (soundRef.current) {
        soundRef.current.unloadAsync();
        soundRef.current = null;
        isLoadedRef.current = false;
      }
    };
  }, []);

  // Pause music
  const pause = async () => {
    try {
      if (soundRef.current && isLoadedRef.current) {
        await soundRef.current.pauseAsync();
      }
    } catch (error) {
      console.error('Error pausing music:', error);
    }
  };

  // Resume music
  const resume = async () => {
    try {
      if (soundRef.current && isLoadedRef.current) {
        await soundRef.current.playAsync();
      }
    } catch (error) {
      console.error('Error resuming music:', error);
    }
  };

  return (
    <OnboardingMusicContext.Provider value={{ pause, resume }}>
      {children}
    </OnboardingMusicContext.Provider>
  );
}

export function useOnboardingMusicControl() {
  const context = useContext(OnboardingMusicContext);
  if (!context) {
    throw new Error('useOnboardingMusicControl must be used within OnboardingMusicProvider');
  }
  return context;
}
