import React, { useState, useEffect, useRef } from 'react';
import { View, Text, StyleSheet, Animated, TouchableOpacity } from 'react-native';
import AnimatedBackground from '../../components/AnimatedBackground';
import QuitOnboardingButton from '../../components/QuitOnboardingButton';
import { COLORS, SPACING } from '../../constants/colors';
import { CINEMATIC_MESSAGES } from '../../constants/onboardingData';
import { SHOW_FREE_FOREVER } from '../../config/features';

const FADE_DURATION = 300; // 300ms for fade in
const FADE_OUT_DURATION = 600; // 600ms for fade out (slower)

// Confetti particle component
const ConfettiParticle = ({ delay, color, side }) => {
  const translateY = useRef(new Animated.Value(-100)).current; // Start from top
  const translateX = useRef(new Animated.Value(0)).current;
  const rotate = useRef(new Animated.Value(0)).current;
  const opacity = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    setTimeout(() => {
      // Calculate arc trajectory
      const horizontalDistance = side === 'left' ?
        (Math.random() * 150 + 100) : // Spray right from left side
        -(Math.random() * 150 + 100); // Spray left from right side

      const upwardForce = -(Math.random() * 200 + 150); // Shoot upward first
      const downwardDistance = 600; // Then fall down

      Animated.parallel([
        // Fade in quickly
        Animated.timing(opacity, {
          toValue: 1,
          duration: 100,
          useNativeDriver: true,
        }),
        // Arc motion: shoot up then fall down (parabola)
        Animated.sequence([
          // Shoot up
          Animated.timing(translateY, {
            toValue: upwardForce,
            duration: 800,
            useNativeDriver: true,
          }),
          // Fall down with gravity
          Animated.timing(translateY, {
            toValue: downwardDistance,
            duration: 1500,
            useNativeDriver: true,
          }),
        ]),
        // Horizontal spray toward center
        Animated.timing(translateX, {
          toValue: horizontalDistance,
          duration: 2300,
          useNativeDriver: true,
        }),
        // Continuous rotation
        Animated.timing(rotate, {
          toValue: Math.random() * 1080, // Multiple rotations
          duration: 2300,
          useNativeDriver: true,
        }),
      ]).start();

      // Fade out before hitting bottom
      setTimeout(() => {
        Animated.timing(opacity, {
          toValue: 0,
          duration: 400,
          useNativeDriver: true,
        }).start();
      }, 1900);
    }, delay);
  }, []);

  return (
    <Animated.View
      style={[
        styles.confettiParticle,
        {
          backgroundColor: color,
          opacity,
          transform: [
            { translateX },
            { translateY },
            { rotate: rotate.interpolate({
              inputRange: [0, 360],
              outputRange: ['0deg', '360deg'],
            })},
          ],
        },
      ]}
    />
  );
};

export default function CinematicScreen({ navigation }) {
  const [showConfetti, setShowConfetti] = useState(false);

  const fadeAnims = useRef([
    new Animated.Value(0),
    new Animated.Value(0),
    new Animated.Value(0),
  ]).current;

  // Pulse animations for all messages (subtle for first two, stronger for last)
  const pulseAnims = useRef([
    new Animated.Value(1),
    new Animated.Value(1),
    new Animated.Value(1),
  ]).current;

  useEffect(() => {
    // Very subtle pulse for first two messages
    [0, 1].forEach((index) => {
      Animated.loop(
        Animated.sequence([
          Animated.timing(pulseAnims[index], {
            toValue: 1.02, // Very subtle
            duration: 1200,
            useNativeDriver: true,
          }),
          Animated.timing(pulseAnims[index], {
            toValue: 1,
            duration: 1200,
            useNativeDriver: true,
          }),
        ])
      ).start();
    });

    // Stronger pulse for last message
    Animated.loop(
      Animated.sequence([
        Animated.timing(pulseAnims[2], {
          toValue: 1.05,
          duration: 1000,
          useNativeDriver: true,
        }),
        Animated.timing(pulseAnims[2], {
          toValue: 1,
          duration: 1000,
          useNativeDriver: true,
        }),
      ])
    ).start();

    // Custom timing sequence:
    // 0s: First message fades in
    // 1s: Second message fades in (overlap with first for 0.5s)
    // 1.5s: First message fades out (slowly)
    // 3s: Last message fades in (second fades out slowly)
    // 3.5s: Confetti
    // 4.5s: Navigate

    // First message: fade in at 0s
    Animated.timing(fadeAnims[0], {
      toValue: 1,
      duration: FADE_DURATION,
      useNativeDriver: true,
    }).start();

    // First message: fade out at 1.5s (slowly)
    setTimeout(() => {
      Animated.timing(fadeAnims[0], {
        toValue: 0,
        duration: FADE_OUT_DURATION,
        useNativeDriver: true,
      }).start();
    }, 1500);

    // Second message: fade in at 1s
    setTimeout(() => {
      Animated.timing(fadeAnims[1], {
        toValue: 1,
        duration: FADE_DURATION,
        useNativeDriver: true,
      }).start();
    }, 1000);

    // Second message: fade out at 3s (slowly)
    setTimeout(() => {
      Animated.timing(fadeAnims[1], {
        toValue: 0,
        duration: FADE_OUT_DURATION,
        useNativeDriver: true,
      }).start();
    }, 3000);

    // Last message: fade in at 3s
    setTimeout(() => {
      Animated.timing(fadeAnims[2], {
        toValue: 1,
        duration: FADE_DURATION,
        useNativeDriver: true,
      }).start();
    }, 3000);

    // Confetti: show at 3.5s
    setTimeout(() => {
      console.log('Showing confetti now!');
      setShowConfetti(true);
    }, 3500);

    // Navigate at 4.5s
    setTimeout(() => {
      navigation.navigate('Paywall');
    }, 4500);
  }, []);

  const handleSkip = () => {
    navigation.navigate('Paywall');
  };

  return (
    <View style={styles.container}>
      <AnimatedBackground />
      <QuitOnboardingButton />
      {/* Continue button */}
      <TouchableOpacity style={styles.skipButton} onPress={handleSkip}>
        <Text style={styles.skipText}>Continue</Text>
      </TouchableOpacity>

      {/* Animated messages */}
      <View style={styles.messagesContainer}>
        {CINEMATIC_MESSAGES.map((message, index) => {
          const isLastMessage = index === CINEMATIC_MESSAGES.length - 1;
          const isFirstMessage = index === 0;

          return (
            <Animated.View
              key={index}
              style={[
                styles.messageContainer,
                isFirstMessage && styles.firstMessageContainer,
                {
                  opacity: fadeAnims[index],
                  position: 'absolute',
                  transform: [{ scale: pulseAnims[index] }],
                },
              ]}
            >
              {isLastMessage ? (
                SHOW_FREE_FOREVER ? (
                  <View style={styles.freeForeverContainer}>
                    <Text style={styles.regularText}>Practice every day, and the app is</Text>
                    <Animated.View style={styles.freeForeverHighlight}>
                      <Text style={styles.freeForeverText}>FREE FOREVER</Text>
                    </Animated.View>
                  </View>
                ) : (
                  <View style={styles.freeForeverContainer}>
                    <Text style={styles.regularText}>You're all set!</Text>
                    <Animated.View style={styles.freeForeverHighlight}>
                      <Text style={styles.freeForeverText}>LET'S BEGIN</Text>
                    </Animated.View>
                  </View>
                )
              ) : (
                <Text style={[
                  styles.messageText,
                  index === 0 && styles.firstMessage,
                  index === 1 && styles.secondMessage,
                ]}>{message}</Text>
              )}
            </Animated.View>
          );
        })}
      </View>

      {/* Custom Confetti Animation */}
      {showConfetti && (
        <View style={styles.confettiContainer}>
          {Array.from({ length: 60 }).map((_, i) => {
            const side = i % 2 === 0 ? 'left' : 'right'; // Alternate sides
            return (
              <ConfettiParticle
                key={i}
                delay={Math.random() * 400} // Stagger the burst
                side={side}
                color={[
                  '#FF6B35', // Orange
                  '#F7931E', // Light orange
                  '#4ECDC4', // Teal
                  '#95E1D3', // Light teal
                  '#FFD93D', // Yellow
                  '#6BCF7F', // Green
                  '#E84855', // Red
                  '#9B59B6', // Purple
                ][Math.floor(Math.random() * 8)]}
              />
            );
          })}
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: SPACING.xl,
  },
  skipButton: {
    position: 'absolute',
    top: 60,
    right: SPACING.lg,
    padding: SPACING.sm,
    zIndex: 10,
  },
  skipText: {
    fontSize: 16,
    fontWeight: '600',
    color: COLORS.primary,
  },
  messagesContainer: {
    width: '100%',
    alignItems: 'center',
    justifyContent: 'center',
    minHeight: 200,
  },
  messageContainer: {
    width: '100%',
    alignItems: 'center',
    justifyContent: 'center',
  },
  firstMessageContainer: {
    top: -60, // Position first message above center
  },
  messageText: {
    fontSize: 28,
    fontWeight: '700',
    color: COLORS.text,
    textAlign: 'center',
    lineHeight: 40,
    paddingHorizontal: SPACING.lg,
  },
  firstMessage: {
    fontSize: 30,
    color: COLORS.text,
  },
  secondMessage: {
    fontSize: 28,
    color: COLORS.textSecondary,
  },
  freeForeverContainer: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: SPACING.lg,
  },
  regularText: {
    fontSize: 22,
    fontWeight: '600',
    color: COLORS.text,
    textAlign: 'center',
    marginBottom: SPACING.md,
  },
  freeForeverHighlight: {
    backgroundColor: COLORS.primary,
    borderRadius: 16,
    paddingVertical: SPACING.lg,
    paddingHorizontal: SPACING.xl,
    marginVertical: SPACING.md,
    shadowColor: COLORS.primary,
    shadowOffset: {
      width: 0,
      height: 8,
    },
    shadowOpacity: 0.5,
    shadowRadius: 16,
    elevation: 12,
  },
  freeForeverText: {
    fontSize: 42,
    fontWeight: '900',
    color: '#FFFFFF',
    textAlign: 'center',
    letterSpacing: 2,
    textShadowColor: 'rgba(0, 0, 0, 0.3)',
    textShadowOffset: { width: 0, height: 2 },
    textShadowRadius: 4,
  },
  confettiContainer: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    pointerEvents: 'none',
    zIndex: 999,
  },
  confettiParticle: {
    position: 'absolute',
    width: 12,
    height: 12,
    borderRadius: 2,
    top: '40%', // Start from upper-middle area
    left: '50%', // Center horizontally (will spray left/right from here)
  },
});
