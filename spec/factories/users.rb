FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    
    trait :guest do
      email { "guest@example.com" }
    end
    
    trait :with_sessions do
      after(:create) do |user|
        create_list(:session, 3, user: user)
      end
    end
  end
end