export const VALUE_PROPS = [
  {
    id: 1,
    title: '85% of career success',
    description: 'comes from strong communication skills',
    source: 'Harvard Business Review',
    icon: '🎯',
  },
  {
    id: 2,
    title: '40% higher earnings',
    description: 'for those with excellent communication',
    source: 'National Association of Colleges',
    icon: '📈',
  },
  {
    id: 3,
    title: '1.9M job postings',
    description: 'requiring strong communication skills',
    source: 'LinkedIn, 2023',
    icon: '💼',
  },
  {
    id: 4,
    title: 'Predicts relationship happiness',
    description: 'stronger connections & satisfaction',
    source: 'BioMed Central',
    icon: '✨',
  },
];

export const SPEAKING_GOALS = [
  {
    id: 1,
    title: 'Public Speaking',
    icon: '🎤',
  },
  {
    id: 2,
    title: 'Acing Interviews',
    icon: '💼',
  },
  {
    id: 3,
    title: 'Sales & Pitching',
    icon: '💰',
  },
  {
    id: 4,
    title: 'Podcasting/Content',
    icon: '🎙️',
  },
  {
    id: 5,
    title: 'Social Skills',
    icon: '🤝',
  },
  {
    id: 6,
    title: 'Acting/Performance',
    icon: '🎭',
  },
  {
    id: 7,
    title: 'Leadership',
    icon: '👔',
  },
  {
    id: 8,
    title: 'Other',
    icon: '📝',
  },
];

// Motivation tips based on selected goals
export const MOTIVATION_TIPS = {
  1: {
    title: '78% of people',
    description: 'fear public speaking more than death. You\'re not alone in this journey.',
    source: 'National Social Anxiety Center',
  },
  2: {
    title: '90% of interview success',
    description: 'comes from preparation and delivery, not just your resume.',
    source: 'Career Development Research',
  },
  3: {
    title: 'Top salespeople',
    description: 'practice their pitch 10+ times before every important meeting.',
    source: 'Sales Performance Study',
  },
  4: {
    title: 'Great podcasters',
    description: 'rehearse their delivery daily to sound natural and engaging.',
    source: 'Content Creator Survey',
  },
  5: {
    title: 'Social confidence',
    description: 'grows with every conversation. Each interaction makes you stronger.',
    source: 'Social Psychology Research',
  },
  6: {
    title: 'Every great performer',
    description: 'started as a beginner. Progress, not perfection, is the goal.',
    source: 'Performance Studies',
  },
  7: {
    title: 'Leaders are made',
    description: 'not born. Communication skills can be learned and mastered.',
    source: 'Leadership Development',
  },
  8: {
    title: 'Great communicators',
    description: 'aren\'t born, they\'re built through practice and feedback.',
    source: 'Communication Research',
  },
  default: {
    title: 'Great communicators',
    description: 'aren\'t born, they\'re built through practice and feedback.',
    source: 'Communication Research',
  },
};

export const MOTIVATION_STATS = [
  {
    title: '1% daily improvement',
    description: 'compounds to 37x better in a year. Small steps lead to massive growth.',
    icon: '📈',
    source: 'Atomic Habits',
  },
  {
    title: 'Practice makes permanent',
    description: 'Your brain rewires itself with each practice session. Consistency is key.',
    icon: '🧠',
    source: 'Neuroscience Studies',
  },
];

// Communication styles
export const COMMUNICATION_STYLES = [
  {
    id: 'introvert',
    title: 'Introvert',
    icon: '🤫',
  },
  {
    id: 'extrovert',
    title: 'Extrovert',
    icon: '🗣️',
  },
  {
    id: 'ambivert',
    title: 'Ambivert',
    icon: '⚖️',
  },
  {
    id: 'not_sure',
    title: 'Not Sure',
    icon: '🤔',
  },
];

// Age ranges
export const AGE_RANGES = [
  { id: '18-24', label: '18-24' },
  { id: '25-34', label: '25-34' },
  { id: '35-44', label: '35-44' },
  { id: '45-54', label: '45-54' },
  { id: '55+', label: '55+' },
];

// Languages (using ISO language codes)
export const LANGUAGES = [
  { id: 'en', label: 'English', icon: '🇬🇧' },
  { id: 'pt', label: 'Português', icon: '🇵🇹' },
  { id: 'es', label: 'Español', icon: '🇪🇸' },
  { id: 'fr', label: 'Français', icon: '🇫🇷' },
  { id: 'de', label: 'Deutsch', icon: '🇩🇪' },
  { id: 'it', label: 'Italiano', icon: '🇮🇹' },
  { id: 'nl', label: 'Nederlands', icon: '🇳🇱' },
  { id: 'sv', label: 'Svenska', icon: '🇸🇪' },
  { id: 'da', label: 'Dansk', icon: '🇩🇰' },
  { id: 'no', label: 'Norsk', icon: '🇳🇴' },
  { id: 'tr', label: 'Türkçe', icon: '🇹🇷' },
];

// Trial recording prompt
export const TRIAL_PROMPT = 'What did you enjoy most about last week and why?';

// Mock trial results (used when user skips recording)
export const MOCK_TRIAL_RESULTS = {
  isMockData: true,
  clarity: 72,
  fillerWordsPerMinute: 8.5,
  wordsPerMinute: 145,
  transcript: 'Well, um, my biggest achievement was when I, uh, led a team of 5 people to launch a new product. It was, like, really challenging but we, you know, pulled it off in just 3 months. The experience taught me a lot about, um, communication and, you know, teamwork under pressure.',
};

// Features unlocked with premium
export const UNLOCK_FEATURES = [
  {
    id: 1,
    title: 'AI Coach Recommendations',
    icon: '🤖',
  },
  {
    id: 2,
    title: 'Advanced Metrics',
    subtitle: '(pitch, energy, pauses)',
    icon: '📊',
  },
  {
    id: 3,
    title: 'Custom Improvement Plan',
    icon: '📋',
  },
  {
    id: 4,
    title: 'Progress Tracking',
    icon: '📈',
  },
];

// Pricing plans
export const PRICING_PLANS = [
  {
    id: 'monthly',
    title: 'Monthly',
    price: '$9.99',
    period: '/month',
    badge: null,
  },
  {
    id: 'yearly',
    title: 'Yearly',
    price: '$60',
    period: '/year',
    badge: 'Save 50%!',
    savings: 'Just $5/month',
  },
];

// How it works content
export const HOW_IT_WORKS = {
  title: 'How It Works',
  steps: [
    'Complete a 1-minute session every day',
    'Your free access extends by 24 hours',
    'Stop practicing? Subscription kicks in',
  ],
  icon: '💡',
};

// Cinematic messages
export const CINEMATIC_MESSAGES = [
  'We want you to improve as much as you do!',
  'So we reward consistency',
  'Practice every day, and the app is FREE FOREVER',
];
