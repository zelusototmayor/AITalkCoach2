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

  desc "Send lifetime access email to all lifetime users"
  task send_lifetime_emails: :environment do
    # Find all lifetime users
    users = User.where(subscription_status: "lifetime")

    # Exclude specific emails if needed (e.g., test accounts, your own email)
    excluded_emails = ENV["EXCLUDE"]&.split(",")&.map(&:strip) || []
    users = users.where.not(email: excluded_emails) if excluded_emails.any?

    if users.none?
      puts "No lifetime users found."
      exit
    end

    puts "Found #{users.count} lifetime user(s) to email:"
    users.each { |u| puts "  - #{u.email} (#{u.name})" }

    # Check for auto-confirm flag or prompt for confirmation
    if ENV["CONFIRM"] == "yes"
      puts "\nAuto-confirming due to CONFIRM=yes environment variable"
    else
      print "\nAre you sure you want to send emails to these users? (yes/no): "
      confirmation = STDIN.gets.chomp.downcase

      unless confirmation == "yes"
        puts "Cancelled."
        exit
      end
    end

    sent_count = 0
    failed_count = 0

    users.each do |user|
      begin
        UserMailer.lifetime_access_granted(user).deliver_now
        puts "✓ Sent email to #{user.email}"
        sent_count += 1
      rescue StandardError => e
        puts "✗ Failed to send to #{user.email}: #{e.message}"
        failed_count += 1
      end
    end

    puts "\n" + "=" * 80
    puts "Email sending complete!"
    puts "Successfully sent: #{sent_count}"
    puts "Failed: #{failed_count}"
    puts "=" * 80
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
