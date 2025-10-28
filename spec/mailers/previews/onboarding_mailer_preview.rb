# Preview all emails at http://localhost:3000/rails/mailers/onboarding_mailer
class OnboardingMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/onboarding_mailer/welcome
  def welcome
    user = User.first || User.new(
      name: "Alex Johnson",
      email: "alex@example.com",
      speaking_goal: "Better public speaking",
      onboarding_completed_at: Time.current
    )
    OnboardingMailer.welcome(user)
  end
end
