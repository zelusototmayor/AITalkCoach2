#!/usr/bin/env ruby
require_relative '../config/environment'

# Beta testers with their passwords
beta_testers = [
  { email: "c.nwakibu@gmail.com", first_name: "Chelsea" },
  { email: "Gerezgiher94@gmail.com", first_name: "Aron" },
  { email: "sanjay_hallan@yahoo.co.uk", first_name: "Sanjay" },
  { email: "cassandithomas@icloud.com", first_name: "Cassandra" },
  { email: "mundifamily@yahoo.com", first_name: "Vesta" },
  { email: "ahamed67y@gmail.com", first_name: "MOHAMED" },
  { email: "dea.bace@yahoo.com", first_name: "Mirela" },
  { email: "n_belgrave@hotmail.com", first_name: "Nicholas" }
]

puts "Sending account credentials to #{beta_testers.length} beta testers..."
puts "=" * 80

sent_count = 0
failed_count = 0

beta_testers.each do |tester|
  password = "#{tester[:first_name]}2025"

  begin
    user = User.find_by(email: tester[:email])

    if user.nil?
      puts "✗ User not found: #{tester[:email]}"
      failed_count += 1
      next
    end

    # Send credentials email
    UserMailer.account_credentials(user, password).deliver_now

    puts "✓ Sent credentials email to: #{user.email}"
    puts "  Name: #{user.name}"
    puts "  Password: #{password}"
    puts

    sent_count += 1

  rescue => e
    puts "✗ Failed to send email to #{tester[:email]}: #{e.message}"
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
puts "All users received an email with:"
puts "  - Their name and email"
puts "  - Their password (FirstName2025 format)"
puts "  - Link to login to the app"
puts "  - Link to reset their password if they want to change it"
