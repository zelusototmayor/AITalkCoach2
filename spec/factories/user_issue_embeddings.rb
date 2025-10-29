FactoryBot.define do
  factory :user_issue_embedding do
    user
    embedding_json { "[0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]" }
    payload do
      {
        issue_type: "filler_word",
        context: "um, well, you know",
        session_id: 1,
        timestamp: Time.current.iso8601
      }.to_json
    end

    trait :high_similarity do
      embedding_json { "[0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2, 0.1, 0.0]" }
    end

    trait :low_similarity do
      embedding_json { "[0.0, 0.1, 0.0, 0.1, 0.0, 0.1, 0.0, 0.1, 0.0, 0.1]" }
    end

    trait :pace_issue do
      payload do
        {
          issue_type: "pace_too_fast",
          context: "speaking very quickly",
          session_id: 1,
          timestamp: Time.current.iso8601
        }.to_json
      end
    end

    trait :clarity_issue do
      payload do
        {
          issue_type: "unclear_speech",
          context: "mumbled words",
          session_id: 1,
          timestamp: Time.current.iso8601
        }.to_json
      end
    end
  end
end
