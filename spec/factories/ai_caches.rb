FactoryBot.define do
  factory :ai_cache do
    sequence(:key) { |n| "test_cache_key_#{n}" }
    value { "cached response data" }
    
    trait :expired do
      created_at { 2.days.ago }
    end
    
    trait :json_response do
      value do
        {
          response: "This is a cached AI response",
          confidence: 0.85,
          timestamp: Time.current.iso8601
        }.to_json
      end
    end
    
    trait :embeddings_cache do
      key { "embeddings_user_123_session_456" }
      value { "[0.1, 0.2, 0.3, 0.4, 0.5]" }
    end
  end
end