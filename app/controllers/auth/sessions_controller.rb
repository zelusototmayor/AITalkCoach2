class Auth::SessionsController < ApplicationController
  before_action :require_logout, only: [ :new, :create ]

  def new
    # Login form
  end

  def create
    user = User.find_by(email: params[:session][:email].downcase)

    if user && user.authenticate(params[:session][:password])
      session[:user_id] = user.id

      # For lifetime users who haven't completed onboarding, mark it as completed
      # since they're grandfathered and don't need to go through it
      if user.subscription_lifetime? && !user.onboarding_completed?
        user.update_column(:onboarding_completed_at, Time.current)
        Rails.logger.info "Auto-completed onboarding for grandfathered user: #{user.email}"
      end

      # Check if user needs to complete onboarding
      if user.needs_onboarding?
        redirect_to onboarding_splash_path
        flash[:notice] = "Welcome! Let's get you started."
      else
        redirect_back_or(practice_path)
        flash[:notice] = "Welcome back!"
      end
    else
      flash.now[:alert] = "Invalid email or password"
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    # Log the logout action
    Rails.logger.info "User logging out: #{current_user&.email}"

    # Clear the session completely
    reset_session

    # Clear any cached user data
    @current_user = nil

    # Clear Turbo cache to prevent stale data from being shown
    response.headers["Turbo-Cache-Control"] = "no-cache"

    # Redirect to marketing landing page (root)
    # Note: Flash won't persist across subdomain redirects, which is expected
    redirect_to marketing_subdomain_url("/"), allow_other_host: true
  end

  private

  def session_params
    params.require(:session).permit(:email, :password)
  end
end
