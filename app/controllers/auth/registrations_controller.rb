class Auth::RegistrationsController < ApplicationController
  before_action :require_logout, only: [ :new, :create ]

  def new
    @user = User.new
    # Store trial token in session if provided via URL parameter
    if params[:trial_token].present?
      session[:trial_token] = params[:trial_token]
      @trial_token = params[:trial_token]
    elsif session[:trial_token].present?
      @trial_token = session[:trial_token]
    end
  end

  def create
    @user = User.new(user_params)

    if @user.save
      session[:user_id] = @user.id
      # Store user ID for analytics tracking
      session[:signup_completed_user_id] = @user.id

      # Redirect to onboarding flow
      redirect_to onboarding_welcome_path, notice: "Welcome! Let's get you set up."
    else
      # Preserve trial token on form errors
      session[:trial_token] = params[:trial_token] if params[:trial_token].present?
      render :new, status: :unprocessable_content
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end
end
