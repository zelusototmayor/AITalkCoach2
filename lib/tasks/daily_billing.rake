namespace :billing do
  desc "Process daily billing for users with expired trials"
  task charge_expired_trials: :environment do
    puts "Starting daily billing task at #{Time.current}"

    # Find users whose trials have expired and need to be charged
    # Criteria:
    # - trial_expires_at is in the past
    # - subscription_status is still 'free_trial' (not yet converted to active)
    # - onboarding_completed_at is present (they completed setup)
    users_to_charge = User.where("trial_expires_at < ?", Time.current)
                          .where(subscription_status: "free_trial")
                          .where.not(onboarding_completed_at: nil)
                          .where.not(stripe_payment_method_id: nil)

    puts "Found #{users_to_charge.count} users with expired trials to charge"

    success_count = 0
    failure_count = 0

    users_to_charge.find_each do |user|
      puts "\nProcessing user #{user.id} (#{user.email})"
      puts "  Trial expired at: #{user.trial_expires_at}"
      puts "  Plan: #{user.subscription_plan}"

      begin
        if Billing::ChargeUser.call(user)
          success_count += 1
          puts "  ✓ Successfully charged user #{user.id}"
        else
          failure_count += 1
          puts "  ✗ Failed to charge user #{user.id}"
        end
      rescue StandardError => e
        failure_count += 1
        puts "  ✗ Error charging user #{user.id}: #{e.message}"
        Rails.logger.error "Error in daily billing for user #{user.id}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        Sentry.capture_exception(e) if defined?(Sentry)
      end
    end

    puts "\n" + "=" * 60
    puts "Daily billing task completed at #{Time.current}"
    puts "Successfully charged: #{success_count} users"
    puts "Failed charges: #{failure_count} users"
    puts "=" * 60
  end

  desc "Show users due for billing"
  task preview_expired_trials: :environment do
    users_to_charge = User.where("trial_expires_at < ?", Time.current)
                          .where(subscription_status: "free_trial")
                          .where.not(onboarding_completed_at: nil)
                          .where.not(stripe_payment_method_id: nil)

    puts "\n" + "=" * 60
    puts "Users with expired trials (#{users_to_charge.count} total)"
    puts "=" * 60

    users_to_charge.each do |user|
      amount = user.subscription_plan == "yearly" ? "€60" : "€9.99"
      puts "\nUser ID: #{user.id}"
      puts "Email: #{user.email}"
      puts "Plan: #{user.subscription_plan}"
      puts "Amount: #{amount}"
      puts "Trial expired: #{user.trial_expires_at}"
      puts "Days overdue: #{((Time.current - user.trial_expires_at) / 1.day).ceil}"
    end

    puts "\n" + "=" * 60
  end

  desc "Test charging a specific user by ID"
  task :test_charge, [ :user_id ] => :environment do |t, args|
    unless args[:user_id]
      puts "Usage: rake billing:test_charge[USER_ID]"
      exit
    end

    user = User.find(args[:user_id])
    puts "Testing charge for user #{user.id} (#{user.email})"
    puts "Plan: #{user.subscription_plan}"
    puts "Trial expires: #{user.trial_expires_at}"

    if Billing::ChargeUser.call(user)
      puts "✓ Successfully charged user"
    else
      puts "✗ Failed to charge user"
    end
  end
end
