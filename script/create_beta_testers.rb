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

# Beta testers to create with lifetime access
beta_testers = [
  { first_name: "Zeina", last_name: "Hamza", email: "zeina_hamza@icloud.com" },
  { first_name: "Kenneth", last_name: "Glenn", email: "kennethwglenn@yahoo.com" },
  { first_name: "Adam", last_name: "Werth", email: "Adam878@juno.com" },
  { first_name: "Vedant", last_name: "Pophali", email: "officialvedantpophali2005@gmail.com" },
  { first_name: "James", last_name: "Robinson", email: "graduate252@gmail.com" }
]

puts "Creating #{beta_testers.length} beta tester accounts with lifetime access..."
puts "=" * 80

created_count = 0
failed_count = 0

beta_testers.each do |tester|
  full_name = "#{tester[:first_name]} #{tester[:last_name]}"
  password = "#{tester[:first_name]}2025"

  begin
    # Check if user already exists
    existing_user = User.find_by(email: tester[:email])

    if existing_user
      puts "⚠️  User already exists: #{tester[:email]}"
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

      # Send email
      UserMailer.lifetime_access_granted(existing_user).deliver_now
      puts "   ✓ Sent lifetime access email"

      created_count += 1
    else
      # Create new user
      user = User.create!(
        name: full_name,
        email: tester[:email],
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

      # Send welcome email
      UserMailer.lifetime_access_granted(user).deliver_now
      puts "  ✓ Sent lifetime access email"
      puts

      created_count += 1
    end

  rescue => e
    puts "✗ Failed to create #{tester[:email]}: #{e.message}"
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
puts "  - Password format: FirstName2025 (e.g., Chelsea2025)"
puts "  - Onboarding marked as completed"
puts "  - Welcome email sent to their inbox"
puts
puts "Users can login immediately at your app's login page."
