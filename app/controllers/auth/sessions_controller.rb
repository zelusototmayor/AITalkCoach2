class Auth::SessionsController < ApplicationController
  before_action :require_logout, only: [:new, :create]
  skip_before_action :verify_authenticity_token, only: [:destroy]

  def new
    # Login form
  end

  def create
    user = User.find_by(email: params[:session][:email].downcase)

    if user && user.authenticate(params[:session][:password])
      session[:user_id] = user.id
      redirect_back_or(practice_path)
      flash[:notice] = 'Welcome back!'
    else
      flash.now[:alert] = 'Invalid email or password'
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

    # Redirect to marketing landing page (root)
    # Note: Flash won't persist across subdomain redirects, which is expected
    redirect_to marketing_subdomain_url('/'), allow_other_host: true
  end

  private

  def session_params
    params.require(:session).permit(:email, :password)
  end
end