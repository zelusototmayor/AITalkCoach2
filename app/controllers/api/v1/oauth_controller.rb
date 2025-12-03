class Api::V1::OauthController < Api::V1::BaseController
  skip_before_action :authenticate_request

  # POST /api/v1/auth/google
  # Authenticate with Google ID token from mobile client
  def google
    id_token = params[:id_token]

    if id_token.blank?
      return render json: { success: false, error: "ID token is required" }, status: :bad_request
    end

    begin
      # Verify the Google ID token
      token_data = Auth::OauthTokenVerifier.verify_google(id_token)

      # Find or create user
      result = Auth::OauthUserService.find_or_create_from_oauth(
        provider: :google,
        uid: token_data[:google_uid],
        email: token_data[:email],
        name: token_data[:name] || params[:name]
      )

      user = result[:user]

      # Generate JWT tokens
      token = JsonWebToken.encode(user_id: user.id)
      refresh_token = JsonWebToken.encode(user_id: user.id, type: "refresh", exp: 30.days.from_now.to_i)

      render json: {
        success: true,
        user: user_json(user),
        token: token,
        refresh_token: refresh_token,
        is_new_user: result[:is_new_user],
        was_linked: result[:was_linked]
      }
    rescue Auth::OauthTokenVerifier::VerificationError => e
      Rails.logger.warn "Google OAuth verification failed: #{e.message}"
      render json: { success: false, error: e.message }, status: :unauthorized
    rescue Auth::OauthUserService::OauthError => e
      Rails.logger.error "Google OAuth user creation failed: #{e.message}"
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/auth/apple
  # Authenticate with Apple ID token from mobile client
  def apple
    id_token = params[:id_token]

    if id_token.blank?
      return render json: { success: false, error: "ID token is required" }, status: :bad_request
    end

    begin
      # Verify the Apple ID token
      token_data = Auth::OauthTokenVerifier.verify_apple(id_token)

      # Apple only provides user info on first authorization
      # Client may pass it along from the initial Sign in with Apple response
      user_name = params.dig(:user, :name) || params[:name]
      user_email = token_data[:email] || params.dig(:user, :email)

      # Find or create user
      result = Auth::OauthUserService.find_or_create_from_oauth(
        provider: :apple,
        uid: token_data[:apple_uid],
        email: user_email,
        name: user_name,
        email_hidden: token_data[:email_hidden]
      )

      user = result[:user]

      # Generate JWT tokens
      token = JsonWebToken.encode(user_id: user.id)
      refresh_token = JsonWebToken.encode(user_id: user.id, type: "refresh", exp: 30.days.from_now.to_i)

      render json: {
        success: true,
        user: user_json(user),
        token: token,
        refresh_token: refresh_token,
        is_new_user: result[:is_new_user],
        was_linked: result[:was_linked]
      }
    rescue Auth::OauthTokenVerifier::VerificationError => e
      Rails.logger.warn "Apple OAuth verification failed: #{e.message}"
      render json: { success: false, error: e.message }, status: :unauthorized
    rescue Auth::OauthUserService::OauthError => e
      Rails.logger.error "Apple OAuth user creation failed: #{e.message}"
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    end
  end

  private

  def user_json(user)
    {
      id: user.id,
      name: user.name,
      email: user.email,
      subscription_status: user.subscription_status,
      subscription_display_status: user.subscription_display_status,
      can_access_app: user.can_access_app?,
      trial_active: user.trial_active?,
      trial_hours_remaining: user.trial_hours_remaining,
      onboarding_completed: user.onboarding_completed?,
      preferred_language: user.preferred_language,
      language_display_name: user.language_display_name,
      speaking_style: user.speaking_style,
      age_range: user.age_range,
      target_wpm: user.target_wpm,
      wpm_settings: {
        optimal_range: {
          min: user.optimal_wpm_min,
          max: user.optimal_wpm_max
        },
        acceptable_range: {
          min: user.acceptable_wpm_min,
          max: user.acceptable_wpm_max
        }
      },
      auth_provider: user.auth_provider,
      oauth_user: user.oauth_user?,
      created_at: user.created_at
    }
  end
end
