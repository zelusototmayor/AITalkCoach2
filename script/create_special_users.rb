#!/usr/bin/env ruby

# Force production environment
ENV['RAILS_ENV'] = 'production'
require_relative '../config/environment'

# Safety confirmation
puts "⚠️  WARNING: This script will create users in PRODUCTION!"
puts "=" * 80

if ENV["CONFIRM"] == "yes"
  puts "Auto-confirming due to CONFIRM=yes environment variable"
  puts
else
  print "Type 'yes' to continue: "
  confirmation = STDIN.gets.chomp.downcase
  unless confirmation == 'yes'
    puts "Cancelled."
    exit
  end
  puts
end

# Users to create with lifetime access
users_to_create = [
  { first_name: "babygirl", last_name: "", email: "Tymeishanevins@gmail.com" }
]

puts "Creating #{users_to_create.length} user account(s) with lifetime access..."
puts "=" * 80

created_count = 0
failed_count = 0

users_to_create.each do |user_data|
  full_name = user_data[:last_name].to_s.empty? ? user_data[:first_name] : "#{user_data[:first_name]} #{user_data[:last_name]}"
  password = "#{user_data[:first_name]}2025"

  begin
    # Check if user already exists
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

      # Send account credentials email with the password
      UserMailer.account_credentials(existing_user, password).deliver_now
      puts "   ✓ Sent account credentials email with App Store info"

      created_count += 1
    else
      # Create new user
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

      # Send account credentials email with password
      UserMailer.account_credentials(user, password).deliver_now
      puts "  ✓ Sent account credentials email with App Store info"
      puts

      created_count += 1
    end

  rescue => e
    puts "✗ Failed to create #{user_data[:email]}: #{e.message}"
    puts "  #{e.backtrace.first}"
    puts
    failed_count += 1
  end
end

puts "=" * 80
puts "Summary:"
puts "  ✓ Successfully processed: #{created_count}"
puts "  ✗ Failed: #{failed_count}"
puts
puts "All accounts have:"
puts "  - Lifetime subscription access (no payment needed)"
puts "  - Password format: FirstName2025 (e.g., Anne2025)"
puts "  - Onboarding marked as completed"
puts "  - Account credentials email sent with App Store download link"
puts
puts "Users can login immediately and download the mobile app from the App Store."
