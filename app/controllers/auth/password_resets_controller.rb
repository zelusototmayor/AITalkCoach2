class Auth::PasswordResetsController < ApplicationController
  before_action :require_logout, only: [ :new, :create ]
  before_action :find_user_by_token, only: [ :edit, :update ]
  before_action :check_token_expiration, only: [ :edit, :update ]

  # GET /auth/password/new - Request password reset form
  def new
  end

  # POST /auth/password - Send password reset email
  def create
    # Use constant-time lookup to prevent timing attacks
    user = User.find_by(email: params[:email].to_s.downcase)

    # Always show success message to prevent email enumeration
    if user
      user.generate_reset_password_token!
      UserMailer.password_reset(user).deliver_now
      Rails.logger.info "Password reset requested for user #{user.id}"
    else
      Rails.logger.info "Password reset requested for non-existent email: #{params[:email]}"
    end

    redirect_to app_subdomain_url(login_path),
                notice: "If your email is registered, you will receive password reset instructions shortly."
  end

  # GET /auth/password/edit?token=xxx - Reset password form
  def edit
  end

  # PATCH /auth/password - Update password
  def update
    if params[:password].blank?
      flash.now[:alert] = "Password cannot be blank"
      render :edit, status: :unprocessable_content
      return
    end

    if params[:password] != params[:password_confirmation]
      flash.now[:alert] = "Password confirmation does not match"
      render :edit, status: :unprocessable_content
      return
    end

    begin
      @user.reset_password!(params[:password])
      Rails.logger.info "Password reset completed for user #{@user.id}"
      redirect_to app_subdomain_url(login_path),
                  notice: "Your password has been reset successfully. Please login with your new password."
    rescue ActiveRecord::RecordInvalid => e
      flash.now[:alert] = "Password #{e.record.errors[:password].first}"
      render :edit, status: :unprocessable_content
    end
  end

  private

  def find_user_by_token
    @user = User.find_by_valid_reset_token(params[:token])

    unless @user
      redirect_to app_subdomain_url(new_password_reset_path),
                  alert: "Invalid or expired password reset link. Please request a new one."
    end
  end

  def check_token_expiration
    if @user&.reset_password_token_expired?
      redirect_to app_subdomain_url(new_password_reset_path),
                  alert: "Password reset link has expired. Please request a new one."
    end
  end
end
