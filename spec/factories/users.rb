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

    # Onboarding-related traits
    trait :with_onboarding_completed do
      speaking_goal { "Better public speaking" }
      speaking_style { "Introvert" }
      age_range { "25-34" }
      profession { "Software Engineer" }
      preferred_pronouns { "They/Them" }
      onboarding_completed_at { 1.day.ago }
    end

    trait :with_demo_session do
      after(:create) do |user|
        demo = create(:trial_session, :completed)
        user.update(onboarding_demo_session_id: demo.id)
      end
    end

    trait :with_payment_method do
      stripe_customer_id { "cus_test_#{SecureRandom.hex(8)}" }
      stripe_payment_method_id { "pm_test_#{SecureRandom.hex(8)}" }
      subscription_plan { "monthly" }
    end

    trait :on_free_trial do
      subscription_status { "free_trial" }
      trial_starts_at { 1.hour.ago }
      trial_expires_at { 23.hours.from_now }

      after(:create) do |user|
        # Ensure they have payment method and completed onboarding
        unless user.stripe_payment_method_id
          user.update(
            stripe_customer_id: "cus_test_#{SecureRandom.hex(8)}",
            stripe_payment_method_id: "pm_test_#{SecureRandom.hex(8)}",
            subscription_plan: "monthly"
          )
        end

        unless user.onboarding_completed_at
          user.update(
            onboarding_completed_at: 2.hours.ago,
            speaking_goal: "Better public speaking",
            speaking_style: "Ambivert",
            age_range: "25-34"
          )
        end
      end
    end

    trait :with_active_subscription do
      subscription_status { "active" }
      subscription_plan { "monthly" }
      stripe_customer_id { "cus_test_#{SecureRandom.hex(8)}" }
      stripe_payment_method_id { "pm_test_#{SecureRandom.hex(8)}" }
      current_period_start { 1.day.ago }
      current_period_end { 29.days.from_now }

      after(:create) do |user|
        unless user.onboarding_completed_at
          user.update(onboarding_completed_at: 3.days.ago)
        end
      end
    end

    trait :with_expired_trial do
      subscription_status { "free_trial" }
      trial_starts_at { 2.days.ago }
      trial_expires_at { 1.hour.ago }
      stripe_customer_id { "cus_test_#{SecureRandom.hex(8)}" }
      stripe_payment_method_id { "pm_test_#{SecureRandom.hex(8)}" }
      subscription_plan { "monthly" }

      after(:create) do |user|
        unless user.onboarding_completed_at
          user.update(onboarding_completed_at: 2.days.ago)
        end
      end
    end
  end
end
