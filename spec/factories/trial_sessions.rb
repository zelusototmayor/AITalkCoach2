FactoryBot.define do
  factory :trial_session do
    sequence(:title) { |n| "Trial Session #{n}" }
    language { "en" }
    media_kind { "audio" }
    duration_ms { 30000 } # 30 seconds
    processing_state { "pending" }
    expires_at { 24.hours.from_now }

    trait :completed do
      processing_state { "completed" }
      analysis_data do
        {
          'transcript' => 'This is a test transcript for the trial session.',
          'wpm' => 145,
          'filler_count' => 2,
          'clarity_score' => 85
        }
      end
    end

    trait :with_analysis_data do
      processing_state { "completed" }
      analysis_data do
        {
          'transcript' => 'Hello, um, this is a, uh, practice recording for testing.',
          'wpm' => 140,
          'filler_count' => 3,
          'filler_rate' => 5.2,
          'clarity_score' => 82.5,
          'metrics' => {
            'speaking_rate' => 140,
            'total_words' => 10,
            'total_duration_seconds' => 5.0
          }
        }
      end
    end

    trait :expired do
      expires_at { 1.hour.ago }
    end

    trait :processing do
      processing_state { "processing" }
      duration_ms { 45000 }
    end

    trait :failed do
      processing_state { "failed" }
      analysis_data do
        {
          'error' => 'Processing failed due to audio quality issues'
        }
      end
    end
  end
end
