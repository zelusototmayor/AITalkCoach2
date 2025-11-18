namespace :emails do
  desc "Send App Store launch announcement email to all users"
  task app_store_launch: :environment do
    # Usage: rails emails:app_store_launch
    # Or with excluded emails: rails emails:app_store_launch EXCLUDE="test@example.com,another@example.com"
    # Auto-confirm: CONFIRM=yes rails emails:app_store_launch

    # Find all users
    users = User.all

    # Exclude specific emails if needed (e.g., test accounts)
    excluded_emails = ENV["EXCLUDE"]&.split(",")&.map(&:strip) || []
    users = users.where.not(email: excluded_emails) if excluded_emails.any?

    if users.none?
      puts "No users found."
      exit
    end

    puts "Found #{users.count} user(s) to email:"
    puts "=" * 80
    users.each { |u| puts "  - #{u.email} (#{u.name})" }
    puts "=" * 80

    # Check for auto-confirm flag or prompt for confirmation
    if ENV["CONFIRM"] == "yes"
      puts "\nAuto-confirming due to CONFIRM=yes environment variable"
    else
      print "\nAre you sure you want to send the App Store launch email to these users? (yes/no): "
      confirmation = STDIN.gets.chomp.downcase

      unless confirmation == "yes"
        puts "Cancelled."
        exit
      end
    end

    puts "\nSending emails..."
    puts "-" * 80

    sent_count = 0
    failed_count = 0

    users.each do |user|
      begin
        UserMailer.app_store_launch(user).deliver_now
        puts "✓ Sent email to #{user.email}"
        sent_count += 1

        # Small delay to avoid rate limiting
        sleep 0.1
      rescue StandardError => e
        puts "✗ Failed to send to #{user.email}: #{e.message}"
        failed_count += 1
      end
    end

    puts "\n" + "=" * 80
    puts "Email sending complete!"
    puts "Successfully sent: #{sent_count}"
    puts "Failed: #{failed_count}"
    puts "Total users: #{users.count}"
    puts "=" * 80
  end

  desc "Send test App Store launch email to yourself"
  task test_app_store_launch: :environment do
    # Usage: rails emails:test_app_store_launch EMAIL=your@email.com

    email = ENV["EMAIL"]

    unless email
      puts "ERROR: Please provide an email address"
      puts "Usage: rails emails:test_app_store_launch EMAIL=your@email.com"
      exit
    end

    user = User.find_by(email: email)

    unless user
      puts "ERROR: No user found with email: #{email}"
      exit
    end

    puts "Sending test App Store launch email to #{user.email}..."

    begin
      UserMailer.app_store_launch(user).deliver_now
      puts "✓ Test email sent successfully to #{user.email}"
      puts "\nPlease check your inbox and verify the email looks correct before sending to all users."
    rescue StandardError => e
      puts "✗ Failed to send test email: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end
  end
end
