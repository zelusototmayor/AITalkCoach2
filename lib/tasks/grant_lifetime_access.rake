namespace :users do
  desc "Grant lifetime paid access to existing users"
  task grant_lifetime_access: :environment do
    # You can specify user emails as arguments, or it will apply to all users
    # Usage: rails users:grant_lifetime_access
    # Or with specific emails: rails users:grant_lifetime_access EMAILS="user1@example.com,user2@example.com"

    email_list = ENV["EMAILS"]&.split(",")&.map(&:strip)

    users = if email_list.present?
      User.where(email: email_list)
    else
      User.all
    end

    if users.none?
      puts "No users found."
      exit
    end

    puts "Found #{users.count} user(s) to upgrade to lifetime access:"
    users.each { |u| puts "  - #{u.email} (#{u.name})" }

    # Check for auto-confirm flag or prompt for confirmation
    if ENV["CONFIRM"] == "yes"
      puts "Auto-confirming due to CONFIRM=yes environment variable"
    else
      print "\nAre you sure you want to grant lifetime access to these users? (yes/no): "
      confirmation = STDIN.gets.chomp.downcase

      unless confirmation == "yes"
        puts "Cancelled."
        exit
      end
    end

    far_future_date = 100.years.from_now

    users.each do |user|
      user.update!(
        subscription_status: "lifetime",
        subscription_plan: "lifetime",
        subscription_started_at: Time.current,
        current_period_end: far_future_date,
        trial_expires_at: nil  # Clear trial expiration
      )
      puts "✓ Granted lifetime access to #{user.email}"
    end

    puts "\n#{users.count} user(s) successfully upgraded to lifetime access!"
  end

  desc "Show current subscription status for all users"
  task subscription_status: :environment do
    users = User.all.order(:email)

    if users.none?
      puts "No users found."
      exit
    end

    puts "\nCurrent subscription status for all users:"
    puts "-" * 80

    users.each do |user|
      status_info = [
        "Email: #{user.email}",
        "Status: #{user.subscription_status}",
        "Plan: #{user.subscription_plan || 'N/A'}",
        "Period End: #{user.current_period_end&.strftime('%Y-%m-%d %H:%M') || 'N/A'}",
        "Trial Expires: #{user.trial_expires_at&.strftime('%Y-%m-%d %H:%M') || 'N/A'}"
      ].join(" | ")

      puts status_info
    end

    puts "-" * 80
    puts "Total users: #{users.count}"
  end
end
