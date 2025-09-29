class Auth::SessionsController < ApplicationController
  before_action :require_logout, only: [:new, :create]

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
    session[:user_id] = nil
    redirect_to root_path, notice: 'Logged out successfully'
  end

  private

  def session_params
    params.require(:session).permit(:email, :password)
  end
end