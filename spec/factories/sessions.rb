FactoryBot.define do
  factory :session do
    user
    title { "Sample Session" }
    language { "en" }
    media_kind { "audio" }
    processing_state { "pending" }
    completed { false }
    duration_ms { 30000 }
    target_seconds { 30 }
    analysis_json { "{}" }

    # Add a mock media file for testing
    after(:build) do |session|
      # Create a temporary audio file for testing
      temp_file = Tempfile.new([ 'test_audio', '.webm' ])
      temp_file.write("fake audio content")
      temp_file.rewind

      session.media_files.attach(
        io: temp_file,
        filename: 'test_audio.webm',
        content_type: 'audio/webm'
      )
    end

    trait :completed do
      processing_state { "completed" }
      completed { true }
      analysis_json do
        {
          wpm: 120,
          filler_rate: 0.1,
          clarity_score: 0.85,
          segments: [
            {
              start_ms: 0,
              end_ms: 30000,
              wpm: 120,
              confidence: 0.95
            }
          ]
        }.to_json
      end
    end

    trait :processing do
      processing_state { "processing" }
    end

    trait :failed do
      processing_state { "failed" }
      completed { false }
      incomplete_reason { "Processing failed" }
    end

    trait :with_video do
      media_kind { "video" }
    end

    trait :with_issues do
      after(:create) do |session|
        create_list(:issue, 2, session: session)
      end
    end

    trait :portuguese do
      language { "pt" }
    end
  end
end
