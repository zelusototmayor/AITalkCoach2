import { Easing } from 'react-native-reanimated';

// Spring configurations
export const springConfigs = {
  gentle: {
    damping: 20,
    stiffness: 90,
    mass: 1,
  },
  moderate: {
    damping: 15,
    stiffness: 100,
    mass: 1,
  },
  bouncy: {
    damping: 10,
    stiffness: 100,
    mass: 0.8,
  },
};

// Timing durations
export const durations = {
  fast: 200,
  medium: 400,
  slow: 600,
  extraSlow: 800,
};

// Stagger delays
export const staggerDelays = {
  quick: 60,      // For MotivationScreen (fast stacking)
  medium: 80,     // For GoalsScreen (waterfall)
  slow: 100,      // For ValuePropScreen (directional entrance)
};

// Easing functions
export const easings = {
  easeOut: Easing.out(Easing.cubic),
  easeIn: Easing.in(Easing.cubic),
  easeInOut: Easing.inOut(Easing.cubic),
  elastic: Easing.elastic(1.2),
};

// Common animation values
export const animationValues = {
  // Entrance animations
  slideDistance: 300,
  fadeStart: 0,
  fadeEnd: 1,
  scaleStart: 0.95,
  scaleEnd: 1,

  // Pulse animation
  pulseScaleMin: 1.0,
  pulseScaleMax: 1.05,
  pulseOpacityMin: 0.3,
  pulseOpacityMax: 0.8,
  pulseDuration: 2000,
};

// Preset entrance animations
export const entrancePresets = {
  // Fade + slide from bottom
  fadeSlideUp: {
    initialTranslateY: 100,
    initialOpacity: 0,
    spring: springConfigs.moderate,
  },

  // Fade + slide from left
  fadeSlideLeft: {
    initialTranslateX: -animationValues.slideDistance,
    initialOpacity: 0,
    spring: springConfigs.moderate,
  },

  // Fade + slide from right
  fadeSlideRight: {
    initialTranslateX: animationValues.slideDistance,
    initialOpacity: 0,
    spring: springConfigs.moderate,
  },

  // Fade + scale (pop in)
  fadeScale: {
    initialScale: animationValues.scaleStart,
    initialOpacity: 0,
    spring: springConfigs.gentle,
  },
};
