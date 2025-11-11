#!/usr/bin/env ruby

# Force production environment
ENV['RAILS_ENV'] = 'production'
require_relative '../config/environment'

# Safety confirmation
puts "⚠️  WARNING: This script will send emails from PRODUCTION!"
puts "=" * 80
print "Type 'yes' to continue: "
confirmation = STDIN.gets.chomp.downcase
unless confirmation == 'yes'
  puts "Cancelled."
  exit
end
puts

# Beta testers who received the incorrect link
beta_testers = [
  "c.nwakibu@gmail.com",
  "Gerezgiher94@gmail.com",
  "sanjay_hallan@yahoo.co.uk",
  "cassandithomas@icloud.com",
  "mundifamily@yahoo.com",
  "ahamed67y@gmail.com",
  "dea.bace@yahoo.com",
  "n_belgrave@hotmail.com"
]

puts "Sending link correction email to #{beta_testers.length} beta testers..."
puts "=" * 80

sent_count = 0
failed_count = 0

beta_testers.each do |email|
  begin
    user = User.find_by(email: email)

    if user.nil?
      puts "✗ User not found: #{email}"
      failed_count += 1
      next
    end

    # Send link correction email
    UserMailer.link_correction(user).deliver_now

    puts "✓ Sent correction email to: #{user.email}"
    puts "  Name: #{user.name}"
    puts

    sent_count += 1

  rescue => e
    puts "✗ Failed to send email to #{email}: #{e.message}"
    puts "  #{e.backtrace.first}"
    puts
    failed_count += 1
  end
end

puts "=" * 80
puts "Summary:"
puts "  ✓ Emails sent successfully: #{sent_count}"
puts "  ✗ Failed: #{failed_count}"
puts
puts "Correction emails sent with:"
puts "  - Apology for the incorrect link"
puts "  - Button with correct production URL (aitalkcoach.com)"
puts "  - Reminder that their credentials remain the same"
