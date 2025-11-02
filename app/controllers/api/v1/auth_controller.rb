class Api::V1::AuthController < Api::V1::BaseController
  skip_before_action :authenticate_request, only: [:login, :signup, :refresh]

  # POST /api/v1/auth/login
  def login
    user = User.find_by(email: params[:email]&.downcase)

    if user&.authenticate(params[:password])
      token = JsonWebToken.encode(user_id: user.id)
      refresh_token = JsonWebToken.encode(user_id: user.id, type: 'refresh', exp: 30.days.from_now.to_i)

      render json: {
        success: true,
        user: user_json(user),
        token: token,
        refresh_token: refresh_token
      }
    else
      render json: {
        success: false,
        error: 'Invalid email or password'
      }, status: :unauthorized
    end
  end

  # POST /api/v1/auth/signup
  def signup
    user = User.new(user_params)

    if user.save
      token = JsonWebToken.encode(user_id: user.id)
      refresh_token = JsonWebToken.encode(user_id: user.id, type: 'refresh', exp: 30.days.from_now.to_i)

      render json: {
        success: true,
        user: user_json(user),
        token: token,
        refresh_token: refresh_token
      }
    else
      render json: {
        success: false,
        errors: user.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/auth/refresh
  def refresh
    refresh_token = request.headers['X-Refresh-Token']

    if refresh_token.blank?
      render json: { error: 'Refresh token required' }, status: :unauthorized
      return
    end

    decoded = JsonWebToken.decode(refresh_token)

    if decoded && decoded[:type] == 'refresh'
      user = User.find(decoded[:user_id])
      new_token = JsonWebToken.encode(user_id: user.id)

      render json: {
        success: true,
        token: new_token,
        user: user_json(user)
      }
    else
      render json: { error: 'Invalid refresh token' }, status: :unauthorized
    end
  rescue JWT::ExpiredSignature
    render json: { error: 'Refresh token expired' }, status: :unauthorized
  rescue => e
    render json: { error: 'Invalid refresh token' }, status: :unauthorized
  end

  # GET /api/v1/auth/me
  def me
    render json: {
      success: true,
      user: user_json(current_user)
    }
  end

  # POST /api/v1/auth/logout
  def logout
    # In a JWT system, logout is handled client-side by removing the token
    # We could implement token blacklisting here if needed
    render json: { success: true, message: 'Logged out successfully' }
  end

  # POST /api/v1/auth/forgot_password
  def forgot_password
    user = User.find_by(email: params[:email]&.downcase)

    if user
      user.generate_reset_password_token!
      # TODO: Send password reset email
      # UserMailer.password_reset(user).deliver_later

      render json: {
        success: true,
        message: 'Password reset instructions have been sent to your email'
      }
    else
      # Don't reveal if email exists or not for security
      render json: {
        success: true,
        message: 'If an account exists with this email, you will receive reset instructions'
      }
    end
  end

  # POST /api/v1/auth/reset_password
  def reset_password
    user = User.find_by_valid_reset_token(params[:token])

    if user
      if user.reset_password!(params[:password])
        render json: {
          success: true,
          message: 'Password has been reset successfully'
        }
      else
        render json: {
          success: false,
          errors: user.errors.full_messages
        }, status: :unprocessable_entity
      end
    else
      render json: {
        success: false,
        error: 'Invalid or expired reset token'
      }, status: :unauthorized
    end
  end

  private

  def user_params
    params.permit(:name, :email, :password, :password_confirmation)
  end

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
      created_at: user.created_at
    }
  end
end