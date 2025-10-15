# AI-Powered Filler Word Audit

## Overview

This feature implements a hybrid approach to filler word detection:
1. **Rule-based detection** catches obvious filler words using regex patterns (fast, free)
2. **AI audit** validates context and catches missed instances (accurate, contextual)

## How It Works

### Detection Flow

```
User uploads audio
    ↓
Rule-based detector finds filler words (RuleDetector)
    ↓
AI audits each detection for context (AiRefiner.audit_filler_words_with_ai)
    ↓
    ├─ Validates: "Is this really a filler?"
    ├─ Removes false positives: "like a cheetah" (simile, not filler)
    └─ Adds missed instances: "right", "okay" used as verbal crutches
    ↓
Final refined list shown to user
```

### Files Modified

1. **app/services/ai/prompt_builder.rb**
   - Added `filler_word_audit` to PROMPT_TYPES
   - Created specialized system prompt for filler word analysis
   - Includes context-aware guidelines (e.g., "like" in similes vs. filler)
   - JSON schema for structured AI responses

2. **app/services/analysis/ai_refiner.rb**
   - `audit_filler_words_with_ai`: Main audit method with caching
   - `process_filler_audit_results`: Converts AI output to issue format
   - `classify_rule_issues_with_ai`: Routes filler words separately
   - Helper methods for timing, text matching, and tip generation

3. **config/prompts.yml**
   - Configuration section for filler word audit
   - Adjustable confidence threshold
   - Enable/disable feature flag

## Configuration

Edit `config/prompts.yml`:

```yaml
filler_word_audit:
  enabled: true                    # Toggle AI audit on/off
  min_confidence_threshold: 0.5    # 0.0-1.0 (lower = more permissive)
  context_window_words: 10         # Words of context around filler
  cache_ttl: 21600                 # Cache results for 6 hours
  detect_missed_fillers: true      # Enable AI discovery
  ai_temperature: 0.1              # Lower = more consistent
```

## Key Features

### 1. Context-Aware Validation

**Example:** The word "like"

**False Positive (removed):**
- "moves like a cheetah" → Legitimate simile
- "I'd like to discuss" → Standard phrasing

**True Positive (kept):**
- "So, like, I think we should..." → Verbal crutch
- "It's, like, really important" → Filler usage

### 2. Additional Detection

AI can catch filler words not in the regex rules:
- **Discourse markers:** "right", "okay", "well" (when overused)
- **Hedge words:** "I guess", "maybe" (when weakening statements)
- **Verbal tics:** "anyway", "I mean", "you see"

### 3. Confidence Scoring

Each detection includes AI confidence (0.0-1.0):
- **1.0:** Definitely filler, disrupts flow
- **0.8-0.9:** Very likely filler
- **0.5-0.7:** Borderline case
- **0.3-0.4:** Probably appropriate
- **0.0-0.2:** Clearly appropriate, not filler

Issues below `min_confidence_threshold` are filtered out.

## Testing

### Manual Test

1. Create a test session with known filler words:
```ruby
# In Rails console
session = Session.last
Sessions::ProcessJob.perform_now(session.id)
```

2. Check the logs for audit output:
```
Routing X filler words to AI audit
Filler word audit: Y validated, Z false positives, N missed
```

3. Inspect the refined issues:
```ruby
session.reload
filler_issues = session.issues.where(kind: 'filler_word')
filler_issues.each do |issue|
  puts "#{issue.text} - Confidence: #{issue.metadata['ai_confidence']}"
  puts "Validation: #{issue.metadata['validation_status']}"
  puts "---"
end
```

### Expected Behavior

**Before (Rule-based only):**
- Session 14: Caught "and" incorrectly, missed actual fillers
- High false positive rate for contextual words

**After (With AI Audit):**
- False positives removed (e.g., "like" in similes)
- Additional fillers detected (e.g., "right", "okay")
- Each detection has rationale and confidence score
- Users see only validated, contextual filler words

## Performance

- **Rule detection:** < 100ms (unchanged)
- **AI audit:** ~2-3s per session (cached for 6 hours)
- **Total impact:** +2-3s on first analysis, 0s on cache hit
- **Cost:** ~$0.02-0.05 per audit (depending on transcript length)

## Caching

Results are cached by:
- Transcript content hash
- Language
- Filler word detections

Cache key example:
```ruby
"analysis:filler_word_audit:abc123def:en:v1.0"
```

Cache invalidation:
- Automatic after 6 hours (configurable)
- Manual: `Rails.cache.clear` or restart Redis

## Troubleshooting

### AI audit not running

Check logs for:
```
Skipping AI analysis (disabled or insufficient data)
```

Solution: Ensure `filler_word_audit.enabled: true` in config/prompts.yml

### All filler words being removed

Check confidence threshold:
```yaml
min_confidence_threshold: 0.5  # Try lowering to 0.3
```

### High API costs

Reduce frequency:
```yaml
cache_ttl: 86400  # Cache for 24 hours instead of 6
```

Or disable for some users:
```ruby
# In AiRefiner#initialize
@skip_audit = session.user.free_tier?
```

## Future Enhancements

1. **User feedback loop:** Let users mark false positives/negatives
2. **Personalized patterns:** Learn user-specific filler word habits
3. **Language-specific rules:** Different filler words per language
4. **Real-time suggestions:** Show audit results during recording
5. **Comparative analysis:** "Your 'um' usage improved 40% this week"

## Related Files

- `app/services/analysis/rule_detector.rb` - Rule-based detection
- `config/clarity/en.yml` - Filler word regex patterns
- `app/jobs/sessions/process_job.rb` - Processing pipeline
- `app/services/ai/client.rb` - OpenAI API client
- `app/services/ai/cache.rb` - Caching infrastructure
