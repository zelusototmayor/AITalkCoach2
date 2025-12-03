class Auth::OauthController < ApplicationController
  before_action :require_logout

  # POST /auth/oauth/google
  # Web OAuth callback for Google Sign-In
  def google
    credential = params[:credential]

    if credential.blank?
      flash[:alert] = "Google sign-in failed. Please try again."
      return redirect_to auth_sessions_new_path
    end

    begin
      # Verify the Google ID token
      token_data = ::Auth::OauthTokenVerifier.verify_google(credential)

      # Find or create user
      result = ::Auth::OauthUserService.find_or_create_from_oauth(
        provider: :google,
        uid: token_data[:google_uid],
        email: token_data[:email],
        name: token_data[:name]
      )

      user = result[:user]

      # Log the user in (session-based)
      session[:user_id] = user.id

      # Handle onboarding flow
      handle_post_oauth_redirect(user, result[:is_new_user])
    rescue ::Auth::OauthTokenVerifier::VerificationError => e
      Rails.logger.warn "Google OAuth verification failed: #{e.message}"
      flash[:alert] = "Google sign-in failed: #{e.message}"
      redirect_to auth_sessions_new_path
    rescue ::Auth::OauthUserService::OauthError => e
      Rails.logger.error "Google OAuth user creation failed: #{e.message}"
      flash[:alert] = "Failed to create account: #{e.message}"
      redirect_to auth_sessions_new_path
    end
  end

  # POST /auth/oauth/apple
  # Web OAuth callback for Sign in with Apple
  def apple
    id_token = params[:id_token]

    if id_token.blank?
      flash[:alert] = "Apple sign-in failed. Please try again."
      return redirect_to auth_sessions_new_path
    end

    begin
      # Verify the Apple ID token
      token_data = ::Auth::OauthTokenVerifier.verify_apple(id_token)

      # Apple sends user info in the first authorization only
      # Parse it from the request if available
      user_data = parse_apple_user_data

      # Find or create user
      result = ::Auth::OauthUserService.find_or_create_from_oauth(
        provider: :apple,
        uid: token_data[:apple_uid],
        email: token_data[:email] || user_data[:email],
        name: user_data[:name],
        email_hidden: token_data[:email_hidden]
      )

      user = result[:user]

      # Log the user in (session-based)
      session[:user_id] = user.id

      # Handle onboarding flow
      handle_post_oauth_redirect(user, result[:is_new_user])
    rescue ::Auth::OauthTokenVerifier::VerificationError => e
      Rails.logger.warn "Apple OAuth verification failed: #{e.message}"
      flash[:alert] = "Apple sign-in failed: #{e.message}"
      redirect_to auth_sessions_new_path
    rescue ::Auth::OauthUserService::OauthError => e
      Rails.logger.error "Apple OAuth user creation failed: #{e.message}"
      flash[:alert] = "Failed to create account: #{e.message}"
      redirect_to auth_sessions_new_path
    end
  end

  private

  def parse_apple_user_data
    # Apple provides user data in a 'user' parameter as JSON on first auth
    user_param = params[:user]
    return { name: nil, email: nil } unless user_param.present?

    if user_param.is_a?(String)
      begin
        user_data = JSON.parse(user_param)
      rescue JSON::ParserError
        return { name: nil, email: nil }
      end
    else
      user_data = user_param.to_h
    end

    # Apple provides name as { firstName: "...", lastName: "..." }
    name = nil
    if user_data["name"].present?
      first_name = user_data.dig("name", "firstName")
      last_name = user_data.dig("name", "lastName")
      name = [ first_name, last_name ].compact.join(" ").presence
    end

    {
      name: name,
      email: user_data["email"]
    }
  end

  def handle_post_oauth_redirect(user, is_new_user)
    # For lifetime users, auto-complete onboarding
    if user.subscription_lifetime? && !user.onboarding_completed?
      user.update_column(:onboarding_completed_at, Time.current)
      user.reload
      Rails.logger.info "Auto-completed onboarding for grandfathered user: #{user.email}"
    end

    # Check if user needs onboarding
    if user.needs_onboarding?
      flash[:notice] = is_new_user ? "Welcome! Let's get you started." : "Welcome back! Please complete your profile."
      redirect_to onboarding_splash_path
    else
      flash[:notice] = is_new_user ? "Welcome to AI Talk Coach!" : "Welcome back!"
      redirect_to practice_path
    end
  end
end
