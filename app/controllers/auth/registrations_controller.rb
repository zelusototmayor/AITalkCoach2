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

      # Handle trial session migration if trial_token is present
      trial_token = params[:trial_token] || session[:trial_token]

      if trial_token.present?
        handle_trial_migration(trial_token)
      else
        redirect_to app_subdomain_url(practice_path), notice: "Account created successfully! Welcome to AI Talk Coach!"
      end
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

  def handle_trial_migration(trial_token)
    begin
      # Attempt to migrate the trial session
      migrator = TrialSessionMigrator.new(trial_token, @user)
      migrated_session = migrator.migrate!

      # Clear trial session data from session
      session.delete(:trial_token)
      session.delete(:trial_active)
      session.delete(:trial_used)

      # Redirect to the migrated session with success message
      redirect_to app_subdomain_url(session_path(migrated_session)),
                  notice: "Welcome to AI Talk Coach! Your trial session has been converted to a full analysis with enhanced features!"

      Rails.logger.info "Successfully migrated trial session #{trial_token} for user #{@user.id}"

    rescue TrialSessionMigrator::TrialSessionNotFound
      Rails.logger.warn "Trial session not found during signup: #{trial_token}"
      redirect_to app_subdomain_url(practice_path), notice: "Account created successfully! Your trial session was not found, but you can start practicing immediately."

    rescue TrialSessionMigrator::TrialSessionExpired
      Rails.logger.warn "Expired trial session during signup: #{trial_token}"
      redirect_to app_subdomain_url(practice_path), notice: "Account created successfully! Your trial session has expired, but you can start practicing immediately."

    rescue TrialSessionMigrator::TrialSessionAlreadyMigrated
      Rails.logger.warn "Already migrated trial session during signup: #{trial_token}"
      redirect_to app_subdomain_url(practice_path), notice: "Account created successfully! Welcome to AI Talk Coach!"

    rescue TrialSessionMigrator::MigrationError => e
      Rails.logger.error "Trial session migration failed during signup: #{e.message}"
      # Don't let migration failure prevent successful signup
      redirect_to app_subdomain_url(practice_path),
                  notice: "Account created successfully! There was an issue with your trial session, but you can start practicing immediately.",
                  alert: "Your trial session could not be migrated, but your account is ready to use."

    rescue => e
      Rails.logger.error "Unexpected error during trial migration: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      # Don't let migration failure prevent successful signup
      redirect_to app_subdomain_url(practice_path), notice: "Account created successfully! Welcome to AI Talk Coach!"
    end
  end
end
