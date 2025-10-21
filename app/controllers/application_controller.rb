class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  
  # Error handling
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :record_invalid
  rescue_from StandardError, with: :handle_standard_error
  
  # Request tracking
  before_action :set_request_context

  # Authentication
  helper_method :current_user, :logged_in?, :trial_mode?
  
  private
  
  def record_not_found(exception)
    respond_to do |format|
      format.html { redirect_to root_path, alert: 'Resource not found.' }
      format.json { render json: { error: 'Resource not found' }, status: :not_found }
    end
  end
  
  def record_invalid(exception)
    respond_to do |format|
      format.html { redirect_back(fallback_location: root_path, alert: 'Invalid data provided.') }
      format.json { render json: { error: 'Invalid data', details: exception.record.errors }, status: :unprocessable_content }
    end
  end
  
  def handle_standard_error(exception)
    # In development, don't redirect on errors – show the actual exception to avoid redirect loops
    if Rails.env.development?
      raise exception
    end

    # Log the error with context
    Rails.logger.error "Unhandled exception: #{exception.class} - #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n") if exception.backtrace

    # Report to Sentry in production
    Sentry.capture_exception(exception) if defined?(Sentry)

    # Avoid redirect loop if error happened on root
    safe_location = request.path == root_path ? '/500.html' : root_path

    respond_to do |format|
      format.html do
        if safe_location == '/500.html'
          render file: Rails.root.join('public', '500.html'), layout: false, status: :internal_server_error
        else
          redirect_to safe_location, alert: 'An unexpected error occurred. Please try again.'
        end
      end
      format.json { render json: { error: 'Internal server error' }, status: :internal_server_error }
    end
  end
  
  def set_request_context
    # Set Sentry context if available
    if defined?(Sentry)
      Sentry.configure_scope do |scope|
        scope.set_tag(:controller, controller_name)
        scope.set_tag(:action, action_name)
        scope.set_context(:request, {
          url: request.url,
          method: request.method,
          user_agent: request.user_agent&.truncate(100)
        })
      end
    end
  end

  # Authentication methods
  def current_user
    return @current_user if defined?(@current_user)

    if session[:user_id]
      user = User.find_by(id: session[:user_id])
      unless user
        # Clear stale session if the user no longer exists
        session.delete(:user_id)
      end
      @current_user = user
    else
      @current_user = nil
    end
  end

  def logged_in?
    !!current_user
  end

  def require_login
    unless logged_in?
      store_location
    redirect_to app_subdomain_url(login_path), allow_other_host: true, alert: 'Please login to continue'
    end
  end

  def store_location
    session[:forwarding_url] = request.original_url if request.get?
  end

  def redirect_back_or(default)
    redirect_to(session[:forwarding_url] || default, allow_other_host: true)
    session.delete(:forwarding_url)
  end

  def require_logout
    if logged_in?
      redirect_to practice_path, notice: 'You are already logged in'
    end
  end

  # Subdomain URL helpers
  def app_subdomain_url(path = '/')
    build_subdomain_url('app', path)
  end

  def marketing_subdomain_url(path = '/')
    build_subdomain_url('', path)
  end

  def build_subdomain_url(subdomain, path)
    # Get the base domain from the current request
    base_domain = if Rails.env.development?
      'aitalkcoach.local'
    else
      'aitalkcoach.com'
    end

    # Build the full host
    host = if subdomain.present?
      "#{subdomain}.#{base_domain}"
    else
      base_domain
    end

    # Use HTTPS in all environments (development now supports SSL for getUserMedia)
    protocol = 'https://'

    # Include port for development
    port = Rails.env.development? ? ":#{request.port}" : ''

    # Build the full URL
    "#{protocol}#{host}#{port}#{path}"
  end

  helper_method :app_subdomain_url, :marketing_subdomain_url

  # Trial mode detection
  def trial_mode?
    !logged_in? && session[:trial_active]
  end

  def activate_trial
    session[:trial_active] = true
    session[:trial_started_at] = Time.current
  end

  def trial_used?
    session[:trial_used].present?
  end

  def mark_trial_used
    session[:trial_used] = true
  end
end
