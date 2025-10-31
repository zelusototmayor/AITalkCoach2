// Mock data for the main practice screen

// Practice prompts that users can shuffle through
export const PRACTICE_PROMPTS = [
  {
    id: 1,
    text: 'What did you enjoy most about last week and why?',
    category: 'Reflection',
    duration: 60,
  },
  {
    id: 2,
    text: 'Describe your ideal weekend in detail.',
    category: 'Personal',
    duration: 60,
  },
  {
    id: 3,
    text: 'What are you most passionate about and why?',
    category: 'Passion',
    duration: 60,
  },
  {
    id: 4,
    text: 'Tell me about a challenge you overcame recently.',
    category: 'Growth',
    duration: 60,
  },
  {
    id: 5,
    text: 'What skills would you like to develop this year?',
    category: 'Goals',
    duration: 60,
  },
  {
    id: 6,
    text: 'Describe a moment when you felt truly proud of yourself.',
    category: 'Achievement',
    duration: 60,
  },
  {
    id: 7,
    text: 'What advice would you give to your younger self?',
    category: 'Wisdom',
    duration: 60,
  },
  {
    id: 8,
    text: 'What does success mean to you personally?',
    category: 'Values',
    duration: 60,
  },
];

// Time options for recording
export const TIME_OPTIONS = [
  { value: 30, label: '30s' },
  { value: 60, label: '60s' },
  { value: 90, label: '90s' },
  { value: 120, label: '120s' },
  { value: 180, label: '180s' },
];

// Mock 7-day average metrics
export const MOCK_SEVEN_DAY_METRICS = {
  overall: {
    value: 78,
    label: 'Overall',
    icon: null, // Remove emoji, will use SVG if needed
  },
  filler: {
    value: '6.2%',
    label: 'Filler',
    icon: null, // Remove emoji, will use SVG if needed
  },
  wpm: {
    value: 148,
    label: 'Words/min',
    icon: null, // Remove emoji, will use SVG if needed
  },
};

// Mock weekly focus data
export const MOCK_WEEKLY_FOCUS = {
  title: 'Reduce filler words',
  tip: 'Pause instead of using "um" or "like"',
  today: {
    completed: 0,
    goal: 2,
  },
  week: {
    completed: 0,
    goal: 10,
  },
  streak: {
    days: 0,
  },
};

// Navigation items
export const NAV_ITEMS = [
  {
    id: 'progress',
    icon: 'trending-up',
    label: 'Progress',
    screen: 'Progress',
  },
  {
    id: 'history',
    icon: 'time-outline',
    label: 'History',
    screen: 'History',
  },
  {
    id: 'practice',
    icon: 'mic',
    label: 'Practice',
    screen: 'Practice',
  },
  {
    id: 'prompts',
    icon: 'bulb-outline',
    label: 'Prompts',
    screen: 'Prompts',
  },
  {
    id: 'profile',
    icon: 'person-outline',
    label: 'Profile',
    screen: 'Profile',
  },
];
