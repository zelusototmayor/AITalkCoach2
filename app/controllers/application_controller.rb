class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  
  # Error handling
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :record_invalid
  rescue_from StandardError, with: :handle_standard_error
  
  # Request tracking
  before_action :set_request_context
  
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
    # Log the error with context
    Rails.logger.error "Unhandled exception: #{exception.class} - #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n") if exception.backtrace
    
    # Report to Sentry in production
    Sentry.capture_exception(exception) if defined?(Sentry)
    
    respond_to do |format|
      format.html { redirect_to root_path, alert: 'An unexpected error occurred. Please try again.' }
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
end
