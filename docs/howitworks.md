# AI Talk Coach - How It Works: Complete Audio Analysis Breakdown

## Overview: 6-Step Analysis Pipeline

The AI Talk Coach audio analysis follows a sophisticated 6-step pipeline that transforms raw audio into actionable speaking insights:

**Audio Upload → Media Extraction → Speech-to-Text → Rule Detection → AI Refinement → Metrics Calculation → User Dashboard**

---

## Step 1: Media Extraction & Processing
**Location**: `app/services/media/extractor.rb`

**What happens:**
- Extracts pure audio from uploaded video/audio files
- Normalizes format to WAV for consistent processing
- Validates file integrity and duration (minimum 1 second)
- Generates metadata: duration, sample rate, file size

**Logic:**
- Supports various formats (MP4, MP3, MOV, WAV, etc.)
- Rejects corrupted or empty files
- Creates temporary working files for pipeline processing

---

## Step 2: Speech-to-Text Transcription
**Location**: `app/services/stt/deepgram_client.rb` via `app/jobs/sessions/process_job.rb:133`

**What happens:**
- Sends audio to Deepgram API for high-accuracy transcription
- Generates word-level timestamps (precise to milliseconds)
- Creates complete transcript with punctuation

**Technical details:**
- Uses Nova-2 model for English/Portuguese, Nova for others
- Enables punctuation, timestamps, and utterances
- Each word gets: `{ word: "hello", start: 1234, end: 1567, confidence: 0.95 }`

**Why this matters:**
- Word-level timing enables precise issue detection
- High accuracy transcription ensures reliable analysis
- Timestamps allow pinpointing exact problem moments

---

## Step 3: Rule-Based Analysis
**Location**: `app/services/analysis/rule_detector.rb`

**What happens:**
- Scans transcript for predefined speech issues using regex patterns
- Calculates baseline metrics (WPM, pauses, filler rates)
- Detects common problems before AI refinement

**Issue Detection Logic:**

### Filler Words
```ruby
filler_patterns = {
  'um' => /\b(um|uhm|uh)\b/i,
  'like' => /\blike\b/i,
  'you_know' => /\byou know\b/i,
  'so' => /\bso\b(?!\s+(that|what))/i
}
```

### Speaking Rate
- **Too Slow**: < 120 WPM
- **Optimal**: 140-160 WPM
- **Too Fast**: > 180 WPM

### Long Pauses
- Detects gaps > 3 seconds between words
- Uses word timestamps: `next_word[:start] - current_word[:end]`

### Repetition Patterns
- Identifies repeated phrases and words
- Groups nearby matches within context windows

---

## Step 4: AI Refinement with GPT-4
**Location**: `app/services/analysis/ai_refiner.rb`

**This is where the magic happens** - AI analyzes your speech contextually:

### Segment Selection
- Builds analysis candidates from transcript segments
- Evaluates each segment for AI analysis potential
- Selects top 5 segments worth detailed AI review

### AI Analysis Process
**For each selected segment:**

1. **Context Building**: Provides AI with segment text, duration, word count, detected issues
2. **Prompt Engineering**: Uses specialized prompts based on user level (beginner/intermediate/advanced)
3. **AI Assessment**: GPT-5 analyzes for:
   - Speech clarity and flow
   - Professional communication effectiveness
   - Confidence indicators
   - Engagement patterns
   - Context-appropriate improvements

### Issue Validation
- AI reviews rule-based detections for false positives
- Adds confidence scores to each issue
- Provides enhanced coaching tips
- Filters out irrelevant patterns

### Smart Caching
- 6-hour cache for similar content segments
- Batch processing for efficiency
- Intelligent API usage to minimize costs

---

## Step 5: Comprehensive Metrics Calculation
**Location**: `app/services/analysis/metrics.rb`

**Generates the numbers you see on your dashboard:**

### Words Per Minute (WPM)
```ruby
duration_minutes = duration_ms / 60_000.0
wpm = total_words / duration_minutes
```
- Uses total session duration (including pauses)
- Optimal range: 140-160 WPM

### Filler Rate Percentage
```ruby
total_fillers = count_all_filler_patterns(transcript)
filler_rate = (total_fillers / total_words) * 100
```
- Scans for 7 common filler types
- **Excellent**: 0-2%, **Good**: 2-5%, **High**: 10-15%

### Clarity Score (Weighted)
Complex calculation combining:
- **Filler penalty** (30% weight): 100 - filler_percentage
- **Pace consistency** (25% weight): Variance in speaking speed
- **Pause quality** (20% weight): Appropriateness of pause durations
- **Articulation** (15% weight): Based on detected speech issues
- **Fluency** (10% weight): Speech flow smoothness

### Pause Analysis
```ruby
words.each_cons(2) do |current, next_word|
  pause_duration = next_word[:start] - current[:end]
end
```
**Categories:**
- **Optimal**: 0.2-0.8 seconds
- **Long**: 1.5-3 seconds
- **Very Long**: >3 seconds

### Overall Score Algorithm
```ruby
overall_score = (
  pace_score * 0.25 +
  clarity_score * 0.35 +
  fluency_score * 0.25 +
  engagement_score * 0.15
)
```

---

## Step 6: Personalized Coaching Recommendations
**Location**: `app/services/analysis/ai_refiner.rb:406`

**AI generates personalized advice by analyzing:**

### User Profile
- Session count and experience level
- Historical improvement patterns
- Previous issue trends over 30 days

### Context-Aware Recommendations
- **Beginner**: Focus on foundational skills
- **Intermediate**: Target specific weaknesses
- **Advanced**: Fine-tune professional presence

### Coaching Logic
```ruby
{
  user_profile: {
    session_count: user_sessions.count,
    level: determine_user_level,
    goals: ['clarity', 'confidence']
  },
  issue_trends: analyze_issue_patterns,
  recent_sessions: last_7_days_performance
}
```

---

## Data Shown to Users: What Each Number Means

### Dashboard Metrics

1. **Overall Score (0-100)**: Weighted combination of all factors
2. **WPM**: Your speaking speed vs optimal range
3. **Filler Rate**: Percentage of words that are fillers
4. **Clarity Score**: How clear and articulate your speech is
5. **Issues Found**: Specific moments needing improvement
6. **Duration Breakdown**: Speaking vs pause time analysis

### Issue Detection
Each issue includes:
- **Exact timing**: When it occurred (start/end milliseconds)
- **Context text**: What you said around that moment
- **Severity**: High/Medium/Low priority
- **Coaching tip**: Specific advice for improvement
- **AI confidence**: How certain the system is about this issue

### Progress Tracking
- **Strengths**: Your top performing areas (80+ scores)
- **Improvement Areas**: Skills needing work (<75 scores)
- **Trends**: Changes over multiple sessions
- **Personalized Goals**: Based on your usage patterns

---

## Why This Approach Works

1. **Precision**: Word-level timestamps enable exact issue pinpointing
2. **Context**: AI understands speech context, not just pattern matching
3. **Personalization**: Recommendations adapt to your skill level
4. **Efficiency**: Smart caching and segment selection optimize AI usage
5. **Accuracy**: Two-stage validation (rules + AI) reduces false positives
6. **Actionability**: Every metric connects to specific improvement advice

The system essentially gives you a personal speech coach that analyzes every word you speak, understands the context, and provides targeted feedback for improvement.