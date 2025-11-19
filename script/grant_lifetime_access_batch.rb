#!/usr/bin/env ruby

# This script grants lifetime access to specified users and sends them notification emails
# For production use via: kamal app exec --reuse "bin/rails runner script/grant_lifetime_access_batch.rb"

# Users to process
users_to_process = [
  { first_name: "Tuna", email: "antonioaccsousacardoso@gmail.com", existing: true },
  { first_name: "Xico", email: "francisco-abf@hotmail.com", existing: true },
  { first_name: "Victor", email: "victor.kzam@gmail.com", existing: true },
  { first_name: "Gabi", email: "tenure_84labs@icloud.com", existing: true },
  { first_name: "Timo", email: "tospe.ami@gmail.com", existing: true },
  { first_name: "Paul", last_name: "Chung", email: "cehyun91@gmail.com", existing: false }
]

puts "=" * 80
puts "Processing #{users_to_process.length} user(s) for lifetime access..."
puts "=" * 80

processed_count = 0
failed_count = 0

users_to_process.each do |user_data|
  begin
    # Check if user exists
    user = User.find_by(email: user_data[:email])

    if user
      # User exists - update to lifetime access
      puts "\nProcessing existing user: #{user_data[:email]}"

      user.update!(
        subscription_status: "lifetime",
        subscription_plan: "lifetime",
        subscription_started_at: Time.current,
        current_period_end: 100.years.from_now,
        trial_expires_at: nil,
        onboarding_completed_at: user.onboarding_completed_at || Time.current
      )

      puts "  ✓ Updated to lifetime access"

      # Generate a password for the email (they can reset if needed)
      password = "#{user_data[:first_name]}2025"

      # Send account credentials email
      UserMailer.account_credentials(user, password).deliver_now
      puts "  ✓ Sent account credentials email"

      processed_count += 1
    else
      if user_data[:existing]
        puts "\n⚠️  Warning: Expected existing user not found: #{user_data[:email]}"
        puts "  Creating new account..."
      else
        puts "\nCreating new user: #{user_data[:email]}"
      end

      # Create new user
      full_name = user_data[:last_name].to_s.empty? ? user_data[:first_name] : "#{user_data[:first_name]} #{user_data[:last_name]}"
      password = "#{user_data[:first_name]}2025"

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

      puts "  ✓ Created account"
      puts "  Name: #{user.name}"
      puts "  Password: #{password}"
      puts "  Status: lifetime"

      # Send account credentials email
      UserMailer.account_credentials(user, password).deliver_now
      puts "  ✓ Sent account credentials email"

      processed_count += 1
    end

  rescue => e
    puts "\n✗ Failed to process #{user_data[:email]}: #{e.message}"
    puts "  #{e.backtrace.first}"
    failed_count += 1
  end
end

puts "\n" + "=" * 80
puts "SUMMARY"
puts "=" * 80
puts "✓ Successfully processed: #{processed_count}"
puts "✗ Failed: #{failed_count}"
puts "\nAll processed accounts have:"
puts "  • Lifetime subscription (no payment required)"
puts "  • Password: FirstName2025 (e.g., Tuna2025, Paul2025)"
puts "  • Account credentials email sent with App Store link"
puts "  • Full access to all features"
puts "\nUsers can login immediately at https://app.aitalkcoach.com"
puts "Mobile app available on the App Store"
puts "=" * 80