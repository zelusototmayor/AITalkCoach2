namespace :subscriptions do
  desc "Upgrade existing accounts to yearly pro plan"
  task upgrade_to_yearly: :environment do
    puts "=" * 80
    puts "UPGRADE EXISTING ACCOUNTS TO YEARLY PRO PLAN"
    puts "=" * 80
    puts ""

    # Get the yearly price ID from environment
    yearly_price_id = ENV.fetch("STRIPE_YEARLY_PRICE_ID", nil)

    if yearly_price_id.blank? || yearly_price_id.include?("placeholder")
      puts "❌ ERROR: STRIPE_YEARLY_PRICE_ID not set in environment!"
      puts "Please set the yearly price ID in your .env file"
      exit 1
    end

    puts "Using yearly price ID: #{yearly_price_id}"
    puts ""

    # You can filter users here - for now, let's ask which users to upgrade
    puts "Which users do you want to upgrade?"
    puts "1. All users"
    puts "2. Specific user by email"
    puts "3. Users with specific subscription status"
    print "\nEnter choice (1-3): "

    choice = STDIN.gets.chomp

    users = case choice
    when "1"
              User.all
    when "2"
              print "Enter email: "
              email = STDIN.gets.chomp
              User.where(email: email)
    when "3"
              print "Enter status (free_trial, active, canceled, past_due): "
              status = STDIN.gets.chomp
              User.where(subscription_status: status)
    else
              puts "Invalid choice"
              exit 1
    end

    puts ""
    puts "Found #{users.count} user(s) to upgrade"
    puts ""

    if users.count == 0
      puts "No users found to upgrade"
      exit 0
    end

    # Show users and confirm
    users.each do |user|
      puts "  - #{user.email} (current status: #{user.subscription_status}, plan: #{user.subscription_plan || 'none'})"
    end
    puts ""

    print "Do you want to proceed with upgrading these users? (yes/no): "
    confirmation = STDIN.gets.chomp.downcase

    unless confirmation == "yes"
      puts "Aborted"
      exit 0
    end

    puts ""
    puts "Starting upgrade process..."
    puts ""

    success_count = 0
    error_count = 0

    users.each do |user|
      begin
        puts "Processing #{user.email}..."

        # Get or create Stripe customer
        customer = user.get_or_create_stripe_customer
        puts "  ✓ Stripe customer: #{customer.id}"

        # Cancel existing subscription if any
        if user.stripe_subscription_id.present?
          begin
            existing_sub = Stripe::Subscription.retrieve(user.stripe_subscription_id)
            if existing_sub.status != "canceled"
              Stripe::Subscription.cancel(user.stripe_subscription_id)
              puts "  ✓ Canceled existing subscription: #{user.stripe_subscription_id}"
            end
          rescue Stripe::InvalidRequestError => e
            puts "  ⚠ Could not cancel existing subscription: #{e.message}"
          end
        end

        # Create new yearly subscription
        subscription = Stripe::Subscription.create(
          customer: customer.id,
          items: [ { price: yearly_price_id } ],
          metadata: {
            user_id: user.id,
            plan: "yearly",
            upgraded_at: Time.current.iso8601,
            upgraded_by: "admin_script"
          }
        )
        puts "  ✓ Created yearly subscription: #{subscription.id}"

        # Update user record
        user.update!(
          stripe_subscription_id: subscription.id,
          subscription_status: "active",
          subscription_plan: "yearly",
          subscription_started_at: Time.at(subscription.current_period_start),
          current_period_end: Time.at(subscription.current_period_end)
        )
        puts "  ✓ Updated user record"
        puts "  ✓ Subscription active until: #{user.current_period_end}"
        puts ""

        success_count += 1

      rescue StandardError => e
        error_count += 1
        puts "  ❌ ERROR: #{e.message}"
        puts "  #{e.backtrace.first}"
        puts ""
      end
    end

    puts "=" * 80
    puts "UPGRADE COMPLETE"
    puts "=" * 80
    puts "Successfully upgraded: #{success_count} user(s)"
    puts "Errors: #{error_count} user(s)"
    puts ""

    if error_count > 0
      puts "⚠ Please review the errors above and manually fix any failed upgrades"
    end
  end

  desc "Upgrade a single user to yearly plan by email"
  task :upgrade_user_to_yearly, [ :email ] => :environment do |t, args|
    unless args[:email]
      puts "Usage: rails subscriptions:upgrade_user_to_yearly[user@example.com]"
      exit 1
    end

    user = User.find_by(email: args[:email])
    unless user
      puts "User not found: #{args[:email]}"
      exit 1
    end

    yearly_price_id = ENV.fetch("STRIPE_YEARLY_PRICE_ID", nil)

    if yearly_price_id.blank? || yearly_price_id.include?("placeholder")
      puts "ERROR: STRIPE_YEARLY_PRICE_ID not set in environment!"
      exit 1
    end

    puts "Upgrading #{user.email} to yearly plan..."
    puts ""

    begin
      # Get or create Stripe customer
      customer = user.get_or_create_stripe_customer
      puts "✓ Stripe customer: #{customer.id}"

      # Cancel existing subscription if any
      if user.stripe_subscription_id.present?
        begin
          existing_sub = Stripe::Subscription.retrieve(user.stripe_subscription_id)
          if existing_sub.status != "canceled"
            Stripe::Subscription.cancel(user.stripe_subscription_id)
            puts "✓ Canceled existing subscription: #{user.stripe_subscription_id}"
          end
        rescue Stripe::InvalidRequestError => e
          puts "⚠ Could not cancel existing subscription: #{e.message}"
        end
      end

      # Create new yearly subscription
      subscription = Stripe::Subscription.create(
        customer: customer.id,
        items: [ { price: yearly_price_id } ],
        metadata: {
          user_id: user.id,
          plan: "yearly",
          upgraded_at: Time.current.iso8601,
          upgraded_by: "admin_script"
        }
      )
      puts "✓ Created yearly subscription: #{subscription.id}"

      # Update user record
      user.update!(
        stripe_subscription_id: subscription.id,
        subscription_status: "active",
        subscription_plan: "yearly",
        subscription_started_at: Time.at(subscription.current_period_start),
        current_period_end: Time.at(subscription.current_period_end)
      )
      puts "✓ Updated user record"
      puts "✓ Subscription active until: #{user.current_period_end}"
      puts ""
      puts "SUCCESS! User upgraded to yearly plan."

    rescue StandardError => e
      puts "ERROR: #{e.message}"
      puts e.backtrace.first
      exit 1
    end
  end
end
