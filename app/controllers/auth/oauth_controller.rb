class Auth::OauthController < ApplicationController
  before_action :require_logout

  # POST /auth/oauth/google
  # Web OAuth callback for Google Sign-In
  # Accepts either:
  #   - credential: Google ID token (from One Tap)
  #   - access_token + user_info: OAuth access token flow (fallback)
  def google
    credential = params[:credential]
    access_token = params[:access_token]
    user_info = params[:user_info]

    begin
      if credential.present?
        # ID token flow (One Tap)
        token_data = ::Auth::OauthTokenVerifier.verify_google(credential)
      elsif access_token.present? && user_info.present?
        # Access token flow (OAuth popup fallback)
        # user_info is already fetched by client from Google's userinfo endpoint
        token_data = {
          email: user_info["email"],
          name: user_info["name"],
          google_uid: user_info["sub"],
          email_verified: user_info["email_verified"]
        }

        unless token_data[:email_verified]
          raise ::Auth::OauthTokenVerifier::VerificationError, "Email not verified with Google"
        end
      else
        flash[:alert] = "Google sign-in failed. Please try again."
        return redirect_or_json_error("Google sign-in failed. Please try again.")
      end

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
      redirect_or_json_error("Google sign-in failed: #{e.message}")
    rescue ::Auth::OauthUserService::OauthError => e
      Rails.logger.error "Google OAuth user creation failed: #{e.message}"
      redirect_or_json_error("Failed to create account: #{e.message}")
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
      redirect_path = onboarding_splash_path
    else
      flash[:notice] = is_new_user ? "Welcome to AI Talk Coach!" : "Welcome back!"
      redirect_path = practice_path
    end

    # Handle JSON requests (from JavaScript OAuth flows)
    if request.format.json? || request.content_type&.include?("application/json")
      render json: { success: true, redirect_url: redirect_path }, status: :ok
    else
      redirect_to redirect_path
    end
  end

  def redirect_or_json_error(message)
    if request.format.json? || request.content_type&.include?("application/json")
      render json: { error: message }, status: :unprocessable_entity
    else
      flash[:alert] = message
      redirect_to auth_sessions_new_path
    end
  end
end
