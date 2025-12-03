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
    # Blacklist the current JWT token if Redis is available
    if $redis && request.headers['Authorization'].present?
      token = request.headers['Authorization'].split(' ').last

      begin
        # Decode token to get expiration time
        decoded = JWT.decode(token, Rails.application.credentials.secret_key_base, true, algorithm: 'HS256')
        jti = decoded[0]['jti'] # JWT ID
        exp = decoded[0]['exp'] # Expiration timestamp

        if jti && exp
          # Store the JTI in Redis with expiration matching token expiration
          # This prevents the token from being used again
          ttl = exp - Time.now.to_i
          if ttl > 0
            $redis.setex("jwt_blacklist:#{jti}", ttl, 'true')
            Rails.logger.info "JWT token blacklisted: #{jti}"
          end
        end
      rescue JWT::DecodeError => e
        Rails.logger.warn "Failed to decode JWT for blacklisting: #{e.message}"
      end
    end

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

  # POST /api/v1/auth/complete_onboarding
  def complete_onboarding
    # Update onboarding completion and demographics
    update_params = {
      onboarding_completed_at: Time.current,
      trial_starts_at: Time.current,
      trial_expires_at: 24.hours.from_now
    }

    # Save demographics from onboarding
    if params[:speaking_style].present?
      update_params[:speaking_style] = params[:speaking_style]
    end

    if params[:age_range].present?
      update_params[:age_range] = params[:age_range]
    end

    if params[:preferred_language].present?
      update_params[:preferred_language] = LanguageService.normalize_language_code(params[:preferred_language])
    end

    current_user.update!(update_params)

    # Migrate trial session to full session if it exists
    if current_user.onboarding_demo_session_id.present?
      trial_session = TrialSession.find_by(id: current_user.onboarding_demo_session_id)

      if trial_session&.completed? && !trial_session.is_mock
        begin
          migrator = TrialSessionMigrator.new(trial_session.token, current_user)
          migrated_session = migrator.migrate!
          Rails.logger.info "Successfully migrated onboarding trial session #{trial_session.id} to session #{migrated_session.id} for user #{current_user.id}"
        rescue => e
          Rails.logger.error "Failed to migrate onboarding trial session: #{e.message}"
        end
      end
    end

    render json: {
      success: true,
      user: user_json(current_user),
      message: "Onboarding completed successfully"
    }
  end

  # PATCH /api/v1/auth/update_profile
  def update_profile
    if current_user.update(profile_params)
      render json: {
        success: true,
        user: user_json(current_user),
        message: "Profile updated successfully"
      }
    else
      render json: {
        success: false,
        errors: current_user.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # PATCH /api/v1/auth/update_language
  def update_language
    normalized_lang = LanguageService.normalize_language_code(params[:language])

    unless LanguageService.language_supported?(normalized_lang)
      render json: {
        success: false,
        error: "Language '#{params[:language]}' is not supported"
      }, status: :unprocessable_entity
      return
    end

    if current_user.update(preferred_language: normalized_lang)
      render json: {
        success: true,
        user: user_json(current_user),
        message: "Language preference updated to #{LanguageService.language_name(normalized_lang)}"
      }
    else
      render json: {
        success: false,
        errors: current_user.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # PATCH /api/v1/auth/update_target_wpm
  def update_target_wpm
    target_wpm = params[:target_wpm]&.to_i

    # Allow nil to reset to defaults
    if target_wpm.nil? || target_wpm == 0
      if current_user.update(target_wpm: nil)
        render json: {
          success: true,
          user: user_json(current_user),
          message: "Target WPM reset to default (#{User::DEFAULT_TARGET_WPM} WPM)"
        }
      else
        render json: {
          success: false,
          errors: current_user.errors.full_messages
        }, status: :unprocessable_entity
      end
      return
    end

    # Validate WPM range
    unless target_wpm.between?(60, 240)
      render json: {
        success: false,
        error: "Target WPM must be between 60 and 240"
      }, status: :unprocessable_entity
      return
    end

    if current_user.update(target_wpm: target_wpm)
      render json: {
        success: true,
        user: user_json(current_user),
        message: "Target WPM updated to #{target_wpm} WPM (optimal range: #{current_user.optimal_wpm_min}-#{current_user.optimal_wpm_max} WPM)",
        wpm_settings: {
          target_wpm: current_user.target_wpm,
          optimal_range: {
            min: current_user.optimal_wpm_min,
            max: current_user.optimal_wpm_max
          },
          acceptable_range: {
            min: current_user.acceptable_wpm_min,
            max: current_user.acceptable_wpm_max
          }
        }
      }
    else
      render json: {
        success: false,
        errors: current_user.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/auth/account
  def delete_account
    user_id = current_user.id
    user_email = current_user.email

    begin
      # Delete the user and all associated data
      # The User model has dependent: :destroy on all associations, so they will be deleted automatically
      current_user.destroy!

      Rails.logger.info "User account deleted: ID #{user_id}, Email: #{user_email}"

      render json: {
        success: true,
        message: "Account deleted successfully"
      }
    rescue => e
      Rails.logger.error "Failed to delete user account #{user_id}: #{e.message}"
      render json: {
        success: false,
        error: "Failed to delete account. Please try again or contact support."
      }, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.permit(:name, :email, :password, :password_confirmation)
  end

  def profile_params
    params.permit(:name, :email, :preferred_language, :speaking_style, :age_range)
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
      created_at: user.created_at
    }
  end
end