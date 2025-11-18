import React, { useEffect, useRef } from 'react';
import { View, Text, StyleSheet } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withDelay,
  withSpring,
  withSequence,
  withTiming,
  Easing
} from 'react-native-reanimated';
import ConfettiCannon from 'react-native-confetti-cannon';
import { LinearGradient } from 'expo-linear-gradient';
import AnimatedBackground from '../../components/AnimatedBackground';
import QuitOnboardingButton from '../../components/QuitOnboardingButton';
import { COLORS, SPACING } from '../../constants/colors';
import { springConfigs, durations } from '../../utils/animationConfigs';

export default function CinematicScreen({ navigation }) {
  const confettiRef = useRef(null);

  // Animation values for each element
  const titleOpacity = useSharedValue(0);
  const titleScale = useSharedValue(0.8);

  const message1Opacity = useSharedValue(0);
  const message1TranslateY = useSharedValue(50);

  const message2Opacity = useSharedValue(0);
  const message2TranslateY = useSharedValue(50);

  const cardOpacity = useSharedValue(0);
  const cardScale = useSharedValue(0.9);
  const cardTranslateY = useSharedValue(30);

  useEffect(() => {
    // Sequence of animations:
    // 0ms: Confetti fires
    // 200ms: Title fades in and scales up
    // 500ms: First message slides up
    // 900ms: Second message slides up
    // 1300ms: Card appears with scale
    // 5000ms: Navigate to next screen (extended by 1.5s for user to enjoy)

    // Fire confetti immediately
    if (confettiRef.current) {
      confettiRef.current.start();
    }

    // Title animation (200ms delay)
    titleOpacity.value = withDelay(
      200,
      withTiming(1, { duration: durations.medium })
    );
    titleScale.value = withDelay(
      200,
      withSpring(1, springConfigs.moderate)
    );

    // First message animation (500ms delay)
    message1Opacity.value = withDelay(
      500,
      withTiming(1, { duration: durations.medium })
    );
    message1TranslateY.value = withDelay(
      500,
      withSpring(0, springConfigs.gentle)
    );

    // Second message animation (900ms delay)
    message2Opacity.value = withDelay(
      900,
      withTiming(1, { duration: durations.medium })
    );
    message2TranslateY.value = withDelay(
      900,
      withSpring(0, springConfigs.gentle)
    );

    // Card animation (1300ms delay)
    cardOpacity.value = withDelay(
      1300,
      withTiming(1, { duration: durations.medium })
    );
    cardScale.value = withDelay(
      1300,
      withSpring(1, springConfigs.moderate)
    );
    cardTranslateY.value = withDelay(
      1300,
      withSpring(0, springConfigs.moderate)
    );

    // Navigate to Paywall after all animations complete (extended to 5s)
    const navigationTimer = setTimeout(() => {
      navigation.navigate('Paywall');
    }, 5000);

    return () => clearTimeout(navigationTimer);
  }, []);

  // Animated styles
  const titleStyle = useAnimatedStyle(() => ({
    opacity: titleOpacity.value,
    transform: [{ scale: titleScale.value }],
  }));

  const message1Style = useAnimatedStyle(() => ({
    opacity: message1Opacity.value,
    transform: [{ translateY: message1TranslateY.value }],
  }));

  const message2Style = useAnimatedStyle(() => ({
    opacity: message2Opacity.value,
    transform: [{ translateY: message2TranslateY.value }],
  }));

  const cardStyle = useAnimatedStyle(() => ({
    opacity: cardOpacity.value,
    transform: [
      { scale: cardScale.value },
      { translateY: cardTranslateY.value }
    ],
  }));

  return (
    <View style={styles.container}>
      <AnimatedBackground />
      <QuitOnboardingButton />

      {/* Confetti from both sides */}
      <ConfettiCannon
        ref={confettiRef}
        count={100}
        origin={{ x: -10, y: 300 }}
        explosionSpeed={350}
        fallSpeed={2500}
        fadeOut={true}
        autoStart={false}
        colors={['#FF6B35', '#F7931E', '#4ECDC4', '#95E1D3', '#FFD93D', '#6BCF7F']}
      />
      <ConfettiCannon
        count={100}
        origin={{ x: 410, y: 300 }}
        explosionSpeed={350}
        fallSpeed={2500}
        fadeOut={true}
        autoStartDelay={0}
        colors={['#FF6B35', '#F7931E', '#4ECDC4', '#95E1D3', '#FFD93D', '#6BCF7F']}
      />

      {/* Content */}
      <View style={styles.contentContainer}>
        {/* Title: Congratulations! */}
        <Animated.View style={titleStyle}>
          <Text style={styles.title}>🎉 Congratulations!</Text>
        </Animated.View>

        {/* First message */}
        <Animated.View style={[styles.messageContainer, message1Style]}>
          <Text style={styles.message}>
            This is the first step to becoming
          </Text>
          <Text style={styles.message}>a more confident speaker.</Text>
        </Animated.View>

        {/* Second message */}
        <Animated.View style={[styles.messageContainer, message2Style]}>
          <Text style={styles.messageHighlight}>
            Just by being here, you're already
          </Text>
          <Text style={styles.messageHighlight}>
            in the top 1% of people taking action.
          </Text>
        </Animated.View>

        {/* Card: Let's start this journey together */}
        <Animated.View style={[styles.card, cardStyle]}>
          <LinearGradient
            colors={[COLORS.primary, '#F7931E']}
            start={{ x: 0, y: 0 }}
            end={{ x: 1, y: 1 }}
            style={styles.cardGradient}
          >
            <Text style={styles.cardText}>Let's start this journey together</Text>
          </LinearGradient>
        </Animated.View>
      </View>
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
  contentContainer: {
    width: '100%',
    alignItems: 'center',
    justifyContent: 'center',
  },
  title: {
    fontSize: 36,
    fontWeight: '900',
    color: COLORS.text,
    textAlign: 'center',
    marginBottom: SPACING.xl,
    letterSpacing: 0.5,
  },
  messageContainer: {
    marginBottom: SPACING.lg,
  },
  message: {
    fontSize: 20,
    fontWeight: '600',
    color: COLORS.text,
    textAlign: 'center',
    lineHeight: 28,
  },
  messageHighlight: {
    fontSize: 18,
    fontWeight: '700',
    color: COLORS.primary,
    textAlign: 'center',
    lineHeight: 26,
  },
  card: {
    marginTop: SPACING.xl,
    width: '90%',
    borderRadius: 20,
    shadowColor: COLORS.primary,
    shadowOffset: {
      width: 0,
      height: 8,
    },
    shadowOpacity: 0.4,
    shadowRadius: 16,
    elevation: 12,
    overflow: 'hidden',
  },
  cardGradient: {
    paddingVertical: SPACING.xl,
    paddingHorizontal: SPACING.lg,
    alignItems: 'center',
    justifyContent: 'center',
  },
  cardText: {
    fontSize: 24,
    fontWeight: '800',
    color: '#FFFFFF',
    textAlign: 'center',
    letterSpacing: 0.5,
    textShadowColor: 'rgba(0, 0, 0, 0.2)',
    textShadowOffset: { width: 0, height: 2 },
    textShadowRadius: 4,
  },
});
