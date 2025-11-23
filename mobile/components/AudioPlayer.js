import React, { useState, useEffect, useImperativeHandle, forwardRef } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ActivityIndicator } from 'react-native';
import { Audio } from 'expo-av';
import Slider from '@react-native-community/slider';
import { COLORS, SPACING } from '../constants/colors';

/**
 * AudioPlayer Component
 * Plays audio with basic controls: play/pause, seekable progress bar, time display
 *
 * @param {string} audioUrl - URL of the audio file to play
 * @param {function} onPlaybackStatusUpdate - Optional callback for playback status changes
 * @param {object} ref - Forwarded ref exposing seekTo and play methods
 */
const AudioPlayer = forwardRef(({ audioUrl, onPlaybackStatusUpdate }, ref) => {
  const [sound, setSound] = useState(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [hasError, setHasError] = useState(false);
  const [duration, setDuration] = useState(0);
  const [position, setPosition] = useState(0);
  const [isBuffering, setIsBuffering] = useState(false);

  // Expose methods to parent via ref
  useImperativeHandle(ref, () => ({
    seekTo: async (positionMs) => {
      if (sound) {
        try {
          await sound.setPositionAsync(positionMs);
        } catch (error) {
          console.error('Error seeking audio:', error);
        }
      }
    },
    play: async () => {
      if (sound) {
        try {
          await sound.playAsync();
        } catch (error) {
          console.error('Error playing audio:', error);
        }
      }
    },
    pause: async () => {
      if (sound) {
        try {
          await sound.pauseAsync();
        } catch (error) {
          console.error('Error pausing audio:', error);
        }
      }
    }
  }));

  // Load audio when URL changes
  useEffect(() => {
    let isMounted = true;

    async function loadAudio() {
      if (!audioUrl) {
        setHasError(true);
        setIsLoading(false);
        return;
      }

      try {
        setIsLoading(true);
        setHasError(false);

        // Set audio mode
        await Audio.setAudioModeAsync({
          playsInSilentModeIOS: true,
          staysActiveInBackground: false,
        });

        // Create and load sound
        const { sound: newSound } = await Audio.Sound.createAsync(
          { uri: audioUrl },
          { shouldPlay: false },
          onPlaybackStatusUpdate_internal
        );

        if (isMounted) {
          setSound(newSound);
          setIsLoading(false);
        }
      } catch (error) {
        console.error('Error loading audio:', error);
        if (isMounted) {
          setHasError(true);
          setIsLoading(false);
        }
      }
    }

    loadAudio();

    // Cleanup
    return () => {
      isMounted = false;
      if (sound) {
        sound.unloadAsync();
      }
    };
  }, [audioUrl]);

  // Handle playback status updates
  function onPlaybackStatusUpdate_internal(status) {
    if (status.isLoaded) {
      setPosition(status.positionMillis);
      setDuration(status.durationMillis || 0);
      setIsPlaying(status.isPlaying);
      setIsBuffering(status.isBuffering);

      // Call external callback if provided
      if (onPlaybackStatusUpdate) {
        onPlaybackStatusUpdate(status);
      }
    } else if (status.error) {
      console.error('Playback error:', status.error);
      setHasError(true);
    }
  }

  // Toggle play/pause
  async function togglePlayPause() {
    if (!sound) return;

    try {
      if (isPlaying) {
        await sound.pauseAsync();
      } else {
        await sound.playAsync();
      }
    } catch (error) {
      console.error('Error toggling playback:', error);
    }
  }

  // Seek to position
  async function handleSliderChange(value) {
    if (!sound) return;

    try {
      const newPosition = value * duration;
      await sound.setPositionAsync(newPosition);
    } catch (error) {
      console.error('Error seeking:', error);
    }
  }

  // Format time (ms to MM:SS)
  function formatTime(ms) {
    const totalSeconds = Math.floor(ms / 1000);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return `${minutes}:${seconds.toString().padStart(2, '0')}`;
  }

  // Render loading state
  if (isLoading) {
    return (
      <View style={styles.container}>
        <ActivityIndicator size="large" color={COLORS.primary} />
        <Text style={styles.statusText}>Loading audio...</Text>
      </View>
    );
  }

  // Render error state
  if (hasError || !audioUrl) {
    return (
      <View style={styles.container}>
        <Text style={styles.errorText}>Audio not available</Text>
      </View>
    );
  }

  // Render player
  return (
    <View style={styles.container}>
      <View style={styles.controlsRow}>
        {/* Play/Pause Button */}
        <TouchableOpacity
          style={styles.playButton}
          onPress={togglePlayPause}
          disabled={isBuffering}
        >
          {isBuffering ? (
            <ActivityIndicator size="small" color="#fff" />
          ) : (
            <Text style={styles.playButtonText}>
              {isPlaying ? '⏸' : '▶'}
            </Text>
          )}
        </TouchableOpacity>

        {/* Progress Bar and Time in Same Row */}
        <View style={styles.progressAndTimeContainer}>
          <Slider
            style={styles.slider}
            minimumValue={0}
            maximumValue={1}
            value={duration > 0 ? position / duration : 0}
            onSlidingComplete={handleSliderChange}
            minimumTrackTintColor={COLORS.primary}
            maximumTrackTintColor="#D1D5DB"
            thumbTintColor={COLORS.primary}
          />
          <Text style={styles.timeText}>
            {formatTime(position)} / {formatTime(duration)}
          </Text>
        </View>
      </View>
    </View>
  );
});

const styles = StyleSheet.create({
  container: {
    backgroundColor: '#F9FAFB',
    borderRadius: 12,
    padding: SPACING.sm,
    marginVertical: SPACING.xs,
  },
  controlsRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  playButton: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: COLORS.primary,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: SPACING.sm,
  },
  playButtonText: {
    fontSize: 16,
    color: '#fff',
  },
  progressAndTimeContainer: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
  },
  slider: {
    flex: 1,
    height: 30,
  },
  timeText: {
    fontSize: 12,
    color: COLORS.textSecondary,
    fontWeight: '500',
    marginLeft: SPACING.sm,
    minWidth: 70,
  },
  statusText: {
    marginTop: SPACING.sm,
    fontSize: 14,
    color: COLORS.textSecondary,
    textAlign: 'center',
  },
  errorText: {
    fontSize: 14,
    color: '#EF4444',
    textAlign: 'center',
  },
});

export default AudioPlayer;
