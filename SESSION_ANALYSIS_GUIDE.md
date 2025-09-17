# AI Talk Coach: Session Analysis & GPT-5 Implementation Guide

This document provides a comprehensive breakdown of how each parameter in your speech analysis sessions is calculated and how the GPT-5 AI analysis works.

## Session Parameters Breakdown

### 1. Words Per Minute (WPM)

**Location**: `app/services/analysis/metrics.rb:235`

```ruby
def calculate_words_per_minute(words, duration_ms)
  return 0 if words.empty? || duration_ms <= 0

  duration_minutes = duration_ms / 60_000.0
  words.length / duration_minutes
end
```

**How it's calculated**:
- Takes the total number of words from the transcript
- Divides by the total session duration in minutes
- Uses the actual media duration, not just speaking time

**Interpretation thresholds**:
- **Optimal range**: 140-160 WPM (natural pace)
- **Acceptable range**: 120-180 WPM
- **Too slow**: < 120 WPM
- **Too fast**: > 180 WPM

### 2. Filler Words Percentage

**Location**: `app/services/analysis/metrics.rb:321`

```ruby
def calculate_filler_metrics(words)
  filler_patterns = {
    'um' => /\b(um|uhm|uh)\b/i,
    'uh' => /\b(uh|er|ah)\b/i,
    'like' => /\blike\b/i,
    'you_know' => /\byou know\b/i,
    'basically' => /\bbasically\b/i,
    'actually' => /\bactually\b/i,
    'so' => /\bso\b(?!\s+(that|what|how|when|where|why))/i
  }

  total_fillers = filler_patterns.sum { |_, pattern| transcript.scan(pattern).length }
  filler_rate = (total_fillers.to_f / total_words * 100)
end
```

**How it's calculated**:
- Scans the transcript for common filler words using regex patterns
- Counts total occurrences of all filler types
- Calculates percentage of total words that are fillers

**Interpretation thresholds**:
- **Excellent**: 0-2%
- **Good**: 2-5%
- **Moderate**: 5-10%
- **High**: 10-15%
- **Very high**: >15%

### 3. Clarity Score

**Location**: `app/services/analysis/metrics.rb:83`

```ruby
CLARITY_WEIGHTS = {
  filler_rate: 0.3,
  pace_consistency: 0.25,
  pause_quality: 0.2,
  articulation: 0.15,
  fluency: 0.1
}.freeze

def calculate_clarity_metrics
  clarity_components = {
    filler_penalty: (100 - filler_metrics[:filler_rate_percentage]).clamp(0, 100),
    pace_score: calculate_pace_clarity_score,
    pause_score: pause_metrics[:pause_quality_score],
    articulation_score: articulation_score,
    fluency_score: calculate_fluency_score(words)
  }

  weighted_clarity = calculate_weighted_score(clarity_components, CLARITY_WEIGHTS)
end
```

**How it's calculated**:
- **Filler penalty** (30% weight): 100 minus filler percentage
- **Pace consistency** (25% weight): Variance in speaking speed across segments
- **Pause quality** (20% weight): Assessment of pause appropriateness and duration
- **Articulation** (15% weight): Based on detected articulation issues
- **Fluency** (10% weight): Smoothness of speech flow

### 4. Issues Found

**Location**: `app/jobs/sessions/process_job.rb:159` and `app/services/analysis/rule_detector.rb`

Issues are detected through a two-stage process:

#### Stage 1: Rule-Based Detection
- **Filler words**: Regex pattern matching
- **Pace issues**: WPM calculation thresholds
- **Long pauses**: >3 second gaps between words
- **Repetition**: Pattern detection for repeated phrases

#### Stage 2: AI Validation & Enhancement
- GPT-5 validates rule-based findings
- Adds context-aware issue detection
- Provides coaching recommendations
- Filters false positives

### 5. Duration Metrics

**Location**: `app/services/analysis/metrics.rb:46`

```ruby
def calculate_basic_metrics
  {
    duration_ms: duration_ms,
    duration_seconds: (duration_ms / 1000.0).round(2),
    speaking_time_ms: calculate_speaking_time(words),
    pause_time_ms: calculate_total_pause_time(words)
  }
end

def calculate_speaking_time(words)
  total_word_duration = 0
  words.each do |word|
    total_word_duration += (word[:end] - word[:start])
  end
  total_word_duration
end
```

**Components**:
- **Total duration**: From media file analysis
- **Speaking time**: Sum of all word durations from transcript timing
- **Pause time**: Total duration minus speaking time

### 6. Pause Analysis

**Location**: `app/services/analysis/metrics.rb:373`

```ruby
def calculate_pause_metrics(words)
  pauses = []
  words.each_cons(2) do |current, next_word|
    pause_duration = next_word[:start] - current[:end]
    pauses << pause_duration if pause_duration > 100 # Ignore very short gaps
  end

  # Quality assessment
  base_score = 100
  if avg_pause > 1500 # 1.5 seconds
    base_score -= 20
  end
  if longest_pause > 5000 # 5 seconds
    base_score -= 30
  end
end
```

**Pause categories**:
- **Optimal**: 0.2-0.8 seconds
- **Acceptable**: 0.8-1.5 seconds
- **Long**: 1.5-3 seconds
- **Very long**: >3 seconds

## GPT-5 Analysis Pipeline

The AI analysis follows a comprehensive 6-step pipeline implemented in `app/jobs/sessions/process_job.rb`:

### Step 1: Media Extraction
**Location**: `app/jobs/sessions/process_job.rb:108`

```ruby
def extract_media
  media_file = @session.media_files.first
  extractor = Media::Extractor.new(media_file)
  extraction_result = extractor.extract_audio_data
end
```

- Extracts audio from uploaded video/audio files
- Normalizes format for transcription
- Validates file integrity and duration

### Step 2: Speech-to-Text Transcription
**Location**: `app/jobs/sessions/process_job.rb:133`

```ruby
def transcribe_speech(media_data)
  stt_client = Stt::DeepgramClient.new

  transcription_options = {
    language: @session.language,
    model: determine_transcription_model,
    punctuate: true,
    diarize: false,
    timestamps: true,
    utterances: true
  }

  transcription_result = stt_client.transcribe_file(media_data[:file_path], transcription_options)
end
```

- Uses Deepgram API for high-accuracy transcription
- Generates word-level timestamps for precise analysis
- Supports multiple languages with optimized models

### Step 3: Rule-Based Analysis
**Location**: `app/jobs/sessions/process_job.rb:159`

```ruby
def analyze_with_rules(transcript_data)
  rule_detector = Analysis::RuleDetector.new(transcript_data, language: @session.language)
  detected_issues = rule_detector.detect_all_issues
end
```

- Applies predefined linguistic rules
- Detects filler words, pace issues, repetition
- Provides baseline issue detection before AI enhancement

### Step 4: GPT-5 AI Refinement
**Location**: `app/jobs/sessions/process_job.rb:179` and `app/services/analysis/ai_refiner.rb`

This is where the GPT-5 magic happens:

#### Segment Selection
```ruby
def select_segments_for_ai_analysis(candidates)
  evaluated_candidates = candidates.map do |candidate|
    evaluation = evaluate_candidate_for_ai_analysis(candidate)
    candidate.merge(ai_evaluation: evaluation)
  end

  selected = evaluated_candidates
    .select { |c| c[:ai_evaluation][:recommended_for_ai_analysis] }
    .sort_by { |c| -c[:ai_evaluation][:evaluation][:overall_score] }
    .first(@max_ai_segments)
end
```

#### AI Analysis Process
```ruby
def analyze_segment_with_ai(segment, transcript_data)
  prompt_builder = Ai::PromptBuilder.new('speech_analysis',
    language: @session.language,
    target_audience: determine_target_audience
  )

  analysis_data = {
    transcript: segment[:text],
    context: {
      duration_seconds: segment[:duration_ms] / 1000.0,
      word_count: segment[:word_count],
      speech_type: determine_speech_type,
      target_audience: determine_target_audience
    },
    detected_issues: find_related_rule_issues(segment)
  }

  response = @ai_client.chat_completion(messages, temperature: 0.3)
end
```

#### Issue Classification & Validation
```ruby
def classify_rule_issues_with_ai(rule_based_issues, transcript_data)
  # Groups issues for batch processing
  issue_groups = rule_based_issues.each_slice(10).to_a

  # AI validates each group and provides:
  # - Confidence scores
  # - False positive detection
  # - Enhanced coaching tips
  # - Severity reassessment
end
```

### Step 5: Comprehensive Metrics Calculation
**Location**: `app/jobs/sessions/process_job.rb:206`

```ruby
def calculate_comprehensive_metrics(transcript_data, issues)
  metrics_calculator = Analysis::Metrics.new(transcript_data, issues, language: @session.language)
  metrics_data = metrics_calculator.calculate_all_metrics
end
```

Combines all data to generate:
- Overall performance scores
- Component breakdowns
- Trend analysis
- Improvement recommendations

### Step 6: Embedding Generation
**Location**: `app/jobs/sessions/process_job.rb:230`

```ruby
def generate_session_embeddings(transcript_data, issues)
  embeddings_service = Ai::Embeddings.new(model: 'text-embedding-3-small')
  embeddings_data = embeddings_service.generate_session_embeddings(@session)
end
```

- Creates vector embeddings for personalization
- Enables pattern recognition across sessions
- Powers adaptive coaching recommendations

## GPT-5 Prompting Strategy

The system uses sophisticated prompting implemented in `app/services/ai/prompt_builder.rb`:

### Context-Aware Analysis
- **User level detection**: Beginner/Intermediate/Advanced based on session count
- **Speech type classification**: Presentation, conversation, etc.
- **Historical pattern recognition**: Previous issues and improvements

### Caching & Optimization
**Location**: `app/services/analysis/ai_refiner.rb:116`

```ruby
def evaluate_candidate_for_ai_analysis(candidate)
  cache_key = Ai::Cache.analysis_cache_key(
    Digest::MD5.hexdigest(candidate[:text]),
    { type: 'segment_evaluation', version: '1.0' }
  )

  cached_result = Ai::Cache.get(cache_key, ttl: @cache_ttl)
  return cached_result if cached_result
end
```

- **6-hour cache TTL** for similar content
- **Intelligent segment selection** to minimize API costs
- **Batch processing** for efficiency

### Coaching Recommendations
**Location**: `app/services/analysis/ai_refiner.rb:406`

```ruby
def generate_coaching_recommendations(merged_issues)
  coaching_data = {
    user_profile: determine_user_profile,
    recent_sessions: determine_recent_sessions,
    issue_trends: analyze_issue_trends(merged_issues)
  }

  # Generates personalized advice based on:
  # - Individual user progress
  # - Historical performance patterns
  # - Specific issue contexts
  # - Learning objectives
end
```

## Data Flow Summary

1. **Upload** → Media file processing
2. **Extract** → Audio normalization
3. **Transcribe** → Deepgram speech-to-text with timestamps
4. **Detect** → Rule-based pattern matching
5. **Analyze** → GPT-5 segment analysis and validation
6. **Calculate** → Comprehensive metrics with weighted scoring
7. **Generate** → Embeddings for personalization
8. **Present** → Real-time dashboard with actionable insights

This multi-layered approach ensures both accuracy and contextual understanding, providing you with precise, actionable feedback for improving your speaking skills.