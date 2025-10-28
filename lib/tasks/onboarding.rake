namespace :onboarding do
  desc "Health check for onboarding funnel"
  task health_check: :environment do
    puts "\n" + "=" * 60
    puts "Onboarding Health Check - #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}"
    puts "=" * 60

    # Users stuck at each screen
    puts "\n📊 Users Stuck at Each Screen:"
    puts "-" * 60

    # Welcome screen: signed up but no speaking_goal
    welcome_stuck = User.where(onboarding_completed_at: nil, speaking_goal: nil).count
    puts "Screen 1 (Welcome): #{welcome_stuck} users"

    # Profile screen: has speaking_goal but no speaking_style
    profile_stuck = User.where(onboarding_completed_at: nil)
                       .where.not(speaking_goal: nil)
                       .where(speaking_style: nil)
                       .count
    puts "Screen 2 (Profile): #{profile_stuck} users"

    # Demographics screen: has speaking_style but no age_range
    demographics_stuck = User.where(onboarding_completed_at: nil)
                            .where.not(speaking_style: nil)
                            .where(age_range: nil)
                            .count
    puts "Screen 3 (Demographics): #{demographics_stuck} users"

    # Test/Pricing screen: has age_range but no payment method
    test_stuck = User.where(onboarding_completed_at: nil)
                    .where.not(age_range: nil)
                    .where(stripe_payment_method_id: nil)
                    .count
    puts "Screen 4/5 (Test/Pricing): #{test_stuck} users"

    # Completion rate by screen
    total_started = User.where.not(created_at: nil).count
    completed_welcome = User.where.not(speaking_goal: nil).count
    completed_profile = User.where.not(speaking_style: nil).count
    completed_demographics = User.where.not(age_range: nil).count
    completed_all = User.where.not(onboarding_completed_at: nil).count

    puts "\n📈 Completion Rate by Screen:"
    puts "-" * 60
    puts "Welcome → Profile: #{percentage(completed_welcome, total_started)}% (#{completed_welcome}/#{total_started})"
    puts "Profile → Demographics: #{percentage(completed_profile, completed_welcome)}% (#{completed_profile}/#{completed_welcome})" if completed_welcome > 0
    puts "Demographics → Payment: #{percentage(completed_demographics, completed_profile)}% (#{completed_demographics}/#{completed_profile})" if completed_profile > 0
    puts "Payment → Completed: #{percentage(completed_all, completed_demographics)}% (#{completed_all}/#{completed_demographics})" if completed_demographics > 0
    puts "Overall Completion: #{percentage(completed_all, total_started)}% (#{completed_all}/#{total_started})"

    # Failed payment methods
    puts "\n💳 Failed Payment Methods:"
    puts "-" * 60
    failed_payments = User.where(onboarding_completed_at: nil)
                         .where.not(age_range: nil)
                         .where(stripe_payment_method_id: nil)
                         .where("created_at > ?", 7.days.ago)
                         .count
    puts "Users who reached payment screen but didn't add card: #{failed_payments}"

    # Expired demos not linked
    puts "\n🔗 Demo Session Linking:"
    puts "-" * 60
    linked_demos = User.where.not(onboarding_demo_session_id: nil).count
    completed_users = User.where.not(onboarding_completed_at: nil).count
    puts "Users with linked demo sessions: #{linked_demos}"
    puts "Demo reuse rate: #{percentage(linked_demos, completed_users)}% (#{linked_demos}/#{completed_users})" if completed_users > 0

    # Time-based analysis
    puts "\n⏰ Time-Based Analysis:"
    puts "-" * 60

    # Users who started onboarding but haven't completed in 24h
    stale_onboarding = User.where(onboarding_completed_at: nil)
                          .where("created_at < ?", 24.hours.ago)
                          .count
    puts "Users stuck >24h: #{stale_onboarding}"

    # Users who started onboarding in last hour (active now)
    recent_starts = User.where(onboarding_completed_at: nil)
                       .where("created_at > ?", 1.hour.ago)
                       .count
    puts "Users who started <1h ago: #{recent_starts}"

    # Average time to complete onboarding
    avg_completion_time = User.where.not(onboarding_completed_at: nil)
                             .where("onboarding_completed_at > created_at")
                             .pluck("EXTRACT(EPOCH FROM (onboarding_completed_at - created_at))")
                             .compact
                             .sum / User.where.not(onboarding_completed_at: nil).count.to_f

    if avg_completion_time > 0
      minutes = (avg_completion_time / 60).round
      puts "Average completion time: #{minutes} minutes"
    end

    puts "\n" + "=" * 60
  end

  desc "Daily onboarding statistics"
  task stats: :environment do
    date = ENV['DATE'] ? Date.parse(ENV['DATE']) : Date.today

    puts "\n" + "=" * 60
    puts "Onboarding Stats for #{date}"
    puts "=" * 60

    # New signups today
    new_signups = User.where(created_at: date.beginning_of_day..date.end_of_day).count
    puts "\nNew signups today: #{new_signups}"

    # Onboarding completion rate
    completed_today = User.where(onboarding_completed_at: date.beginning_of_day..date.end_of_day).count
    completion_rate = percentage(completed_today, new_signups)
    puts "Onboarding completion rate: #{completion_rate}% (#{completed_today}/#{new_signups})"

    # Demo reuse rate
    demos_linked_today = User.where(onboarding_completed_at: date.beginning_of_day..date.end_of_day)
                            .where.not(onboarding_demo_session_id: nil)
                            .count
    demo_rate = percentage(demos_linked_today, new_signups)
    puts "Demo reuse rate: #{demo_rate}% (#{demos_linked_today}/#{new_signups})"

    # Payment collection success
    payments_added_today = User.where(onboarding_completed_at: date.beginning_of_day..date.end_of_day)
                               .where.not(stripe_payment_method_id: nil)
                               .count
    payment_success = percentage(payments_added_today, completed_today)
    puts "Payment collection success: #{payment_success}% (#{payments_added_today}/#{completed_today})" if completed_today > 0

    # Plan selection breakdown
    monthly_today = User.where(onboarding_completed_at: date.beginning_of_day..date.end_of_day)
                       .where(subscription_plan: 'monthly')
                       .count
    yearly_today = User.where(onboarding_completed_at: date.beginning_of_day..date.end_of_day)
                      .where(subscription_plan: 'yearly')
                      .count

    puts "\nPlan selection:"
    puts "  Monthly: #{monthly_today} (#{percentage(monthly_today, completed_today)}%)" if completed_today > 0
    puts "  Yearly: #{yearly_today} (#{percentage(yearly_today, completed_today)}%)" if completed_today > 0

    puts "\n" + "=" * 60
  end

  desc "List users who abandoned onboarding at specific screen"
  task :abandoned, [:screen] => :environment do |t, args|
    screen = args[:screen] || 'all'

    puts "\n" + "=" * 60
    puts "Abandoned Onboarding - Screen: #{screen.upcase}"
    puts "=" * 60

    case screen
    when 'welcome', '1'
      users = User.where(onboarding_completed_at: nil, speaking_goal: nil)
                  .where("created_at < ?", 1.hour.ago)
                  .order(created_at: :desc)
      puts "\nUsers who signed up but never started onboarding:"
    when 'profile', '2'
      users = User.where(onboarding_completed_at: nil)
                  .where.not(speaking_goal: nil)
                  .where(speaking_style: nil)
                  .where("created_at < ?", 1.hour.ago)
                  .order(created_at: :desc)
      puts "\nUsers who abandoned after profile screen:"
    when 'demographics', '3'
      users = User.where(onboarding_completed_at: nil)
                  .where.not(speaking_style: nil)
                  .where(age_range: nil)
                  .where("created_at < ?", 1.hour.ago)
                  .order(created_at: :desc)
      puts "\nUsers who abandoned after demographics screen:"
    when 'payment', '4', '5'
      users = User.where(onboarding_completed_at: nil)
                  .where.not(age_range: nil)
                  .where(stripe_payment_method_id: nil)
                  .where("created_at < ?", 1.hour.ago)
                  .order(created_at: :desc)
      puts "\nUsers who abandoned at payment screen:"
    else
      users = User.where(onboarding_completed_at: nil)
                  .where("created_at < ?", 1.hour.ago)
                  .order(created_at: :desc)
      puts "\nAll users who abandoned onboarding:"
    end

    if users.empty?
      puts "No abandoned users found."
    else
      puts "\nTotal: #{users.count} users\n"
      puts "-" * 60

      users.limit(20).each do |user|
        time_since = time_ago_in_words(user.created_at)
        last_screen = determine_last_screen(user)
        puts "#{user.email.ljust(30)} | Signed up: #{time_since.ljust(15)} | Last screen: #{last_screen}"
      end

      if users.count > 20
        puts "\n(Showing first 20 of #{users.count} users)"
      end
    end

    puts "\n" + "=" * 60
  end

  desc "Send reminder emails to users who abandoned onboarding"
  task send_reminders: :environment do
    puts "\n" + "=" * 60
    puts "Sending Onboarding Reminder Emails"
    puts "=" * 60

    # Users who started onboarding 24h ago but didn't complete
    abandoned_users = User.where(onboarding_completed_at: nil)
                         .where.not(speaking_goal: nil) # At least started
                         .where("created_at BETWEEN ? AND ?", 25.hours.ago, 23.hours.ago)

    puts "\nFound #{abandoned_users.count} users to email..."

    sent_count = 0
    failed_count = 0

    abandoned_users.find_each do |user|
      begin
        OnboardingMailer.reminder(user).deliver_now
        sent_count += 1
        print "."
      rescue StandardError => e
        failed_count += 1
        puts "\n✗ Failed to send to #{user.email}: #{e.message}"
      end
    end

    puts "\n\n" + "=" * 60
    puts "Reminder emails sent: #{sent_count}"
    puts "Failed: #{failed_count}"
    puts "=" * 60
  end

  desc "Generate onboarding funnel report"
  task funnel_report: :environment do
    puts "\n" + "=" * 60
    puts "Onboarding Funnel Report (Last 30 Days)"
    puts "=" * 60

    start_date = 30.days.ago
    end_date = Time.current

    total_signups = User.where(created_at: start_date..end_date).count
    screen_1 = User.where(created_at: start_date..end_date).where.not(speaking_goal: nil).count
    screen_2 = User.where(created_at: start_date..end_date).where.not(speaking_style: nil).count
    screen_3 = User.where(created_at: start_date..end_date).where.not(age_range: nil).count
    screen_4 = User.where(created_at: start_date..end_date).where.not(stripe_payment_method_id: nil).count
    completed = User.where(created_at: start_date..end_date).where.not(onboarding_completed_at: nil).count

    puts "\n📊 Funnel Visualization:"
    puts "-" * 60
    puts "#{bar_chart(total_signups, total_signups)} Signed Up: #{total_signups}"
    puts "#{bar_chart(screen_1, total_signups)} Screen 1 (Goals): #{screen_1} (-#{total_signups - screen_1})"
    puts "#{bar_chart(screen_2, total_signups)} Screen 2 (Style): #{screen_2} (-#{screen_1 - screen_2})"
    puts "#{bar_chart(screen_3, total_signups)} Screen 3 (Demographics): #{screen_3} (-#{screen_2 - screen_3})"
    puts "#{bar_chart(screen_4, total_signups)} Screen 4 (Payment): #{screen_4} (-#{screen_3 - screen_4})"
    puts "#{bar_chart(completed, total_signups)} ✓ Completed: #{completed} (-#{screen_4 - completed})"

    puts "\n📈 Conversion Rates:"
    puts "-" * 60
    puts "Welcome → Profile: #{percentage(screen_1, total_signups)}%"
    puts "Profile → Demographics: #{percentage(screen_2, screen_1)}%" if screen_1 > 0
    puts "Demographics → Payment: #{percentage(screen_3, screen_2)}%" if screen_2 > 0
    puts "Payment → Completed: #{percentage(screen_4, screen_3)}%" if screen_3 > 0
    puts "Overall: #{percentage(completed, total_signups)}%"

    puts "\n" + "=" * 60
  end

  # Helper methods
  def percentage(part, whole)
    return 0 if whole.nil? || whole.zero?
    ((part.to_f / whole) * 100).round(1)
  end

  def time_ago_in_words(time)
    seconds = (Time.current - time).to_i
    return "#{seconds}s ago" if seconds < 60

    minutes = seconds / 60
    return "#{minutes}m ago" if minutes < 60

    hours = minutes / 60
    return "#{hours}h ago" if hours < 24

    days = hours / 24
    "#{days}d ago"
  end

  def determine_last_screen(user)
    return "Payment" if user.age_range.present?
    return "Demographics" if user.speaking_style.present?
    return "Profile" if user.speaking_goal.present?
    "Welcome"
  end

  def bar_chart(value, max, width = 30)
    return "" if max.zero?
    filled = ((value.to_f / max) * width).round
    "█" * filled + "░" * (width - filled)
  end
end
