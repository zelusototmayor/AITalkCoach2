# Preview all emails at http://localhost:3000/rails/mailers/user_mailer
class UserMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/user_mailer/password_reset
  def password_reset
    user = User.first || User.new(
      name: "Alex Johnson",
      email: "alex@example.com",
      reset_password_token: "sample_token_123"
    )
    UserMailer.password_reset(user)
  end

  # Preview this email at http://localhost:3000/rails/mailers/user_mailer/subscription_charged
  def subscription_charged
    user = User.first || User.new(
      name: "Alex Johnson",
      email: "alex@example.com",
      subscription_plan: "yearly",
      current_period_end: 1.year.from_now
    )

    # Mock payment intent data
    payment_intent = {
      'id' => 'pi_test_123456',
      'amount' => 6000, # €60
      'payment_method' => 'pm_test_card1234'
    }

    UserMailer.subscription_charged(user, payment_intent)
  end

  # Preview this email at http://localhost:3000/rails/mailers/user_mailer/payment_failed
  def payment_failed
    user = User.first || User.new(
      name: "Alex Johnson",
      email: "alex@example.com",
      subscription_plan: "monthly"
    )

    error_message = "Your card was declined. Please contact your bank for more information."

    UserMailer.payment_failed(user, error_message)
  end
end
