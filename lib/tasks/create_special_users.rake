namespace :users do
  desc "Create special user accounts with lifetime access and send credentials"
  task create_special_users: :environment do
    # Users to create
    users_to_create = [
      { first_name: "Anne", last_name: "Ricketts", email: "anne@lhctraining.com" },
      { first_name: "Amit", last_name: "Mondal", email: "mamit517@gmail.com" }
    ]

    puts "=" * 80
    puts "Creating #{users_to_create.length} user account(s) with lifetime access..."
    puts "=" * 80

    created_count = 0
    failed_count = 0

    users_to_create.each do |user_data|
      full_name = "#{user_data[:first_name]} #{user_data[:last_name]}"
      password = "#{user_data[:first_name]}2025"

      begin
        existing_user = User.find_by(email: user_data[:email])

        if existing_user
          puts "⚠️  User already exists: #{user_data[:email]}"
          puts "   Updating to lifetime access..."

          existing_user.update!(
            subscription_status: "lifetime",
            subscription_plan: "lifetime",
            subscription_started_at: Time.current,
            current_period_end: 100.years.from_now,
            trial_expires_at: nil,
            onboarding_completed_at: existing_user.onboarding_completed_at || Time.current
          )

          puts "   ✓ Updated to lifetime access"
          UserMailer.account_credentials(existing_user, password).deliver_now
          puts "   ✓ Sent account credentials email with App Store info"
          created_count += 1
        else
          user = User.create!(
            name: full_name,
            email: user_data[:email],
            password: password,
            password_confirmation: password,
            preferred_language: "en",
            subscription_status: "lifetime",
            subscription_plan: "lifetime",
            subscription_started_at: Time.current,
            current_period_end: 100.years.from_now,
            trial_expires_at: nil,
            onboarding_completed_at: Time.current
          )

          puts "✓ Created: #{user.email}"
          puts "  Name: #{user.name}"
          puts "  Password: #{password}"
          puts "  Status: #{user.subscription_status}"
          UserMailer.account_credentials(user, password).deliver_now
          puts "  ✓ Sent account credentials email with App Store info"
          puts
          created_count += 1
        end
      rescue => e
        puts "✗ Failed: #{user_data[:email]}: #{e.message}"
        puts "  #{e.backtrace.first}"
        failed_count += 1
      end
    end

    puts "=" * 80
    puts "Summary:"
    puts "  ✓ Successfully processed: #{created_count}"
    puts "  ✗ Failed: #{failed_count}"
    puts "=" * 80
    puts
    puts "All accounts have:"
    puts "  - Lifetime subscription access (no payment needed)"
    puts "  - Password format: FirstName2025 (e.g., Anne2025)"
    puts "  - Onboarding marked as completed"
    puts "  - Account credentials email sent with App Store download link"
    puts
  end
end
