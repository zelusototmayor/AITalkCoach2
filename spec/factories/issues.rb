FactoryBot.define do
  factory :issue do
    session
    kind { "filler_word" }
    start_ms { 1000 }
    end_ms { 2000 }
    source { "rule" }
    text { "um, well, you know" }
    rationale { "Filler word detected" }
    tip { "Try to reduce filler words" }
    rewrite { "Well, you know" }
    label_confidence { 0.9 }

    trait :ai_detected do
      source { "ai" }
      label_confidence { 0.8 }
    end

    trait :pace_issue do
      kind { "pace_too_fast" }
      rationale { "Speaking too fast" }
      tip { "Try to slow down your speech" }
    end

    trait :clarity_issue do
      kind { "unclear_speech" }
      rationale { "Speech unclear in this segment" }
      tip { "Speak more clearly and enunciate" }
    end

    trait :volume_issue do
      kind { "low_volume" }
      rationale { "Volume too low" }
      tip { "Speak louder or check microphone" }
    end

    trait :long_pause do
      kind { "long_pause" }
      start_ms { 5000 }
      end_ms { 8000 }
      rationale { "Long pause detected" }
      tip { "Try to maintain flow in your speech" }
    end
  end
end
