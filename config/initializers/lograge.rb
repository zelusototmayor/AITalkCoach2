Rails.application.configure do
  # Enable lograge for structured logging
  config.lograge.enabled = true

  # Use JSON formatter for better parsing
  config.lograge.formatter = Lograge::Formatters::Json.new

  # Custom fields to log
  config.lograge.custom_options = lambda do |event|
    {
      time: Time.current.iso8601,
      request_id: event.payload[:request_id],
      user_id: event.payload[:user_id],
      ip: event.payload[:ip],
      user_agent: event.payload[:user_agent]&.truncate(100),
      params: event.payload[:params]&.except("controller", "action", "format", "authenticity_token")&.to_s&.truncate(500),
      exception: event.payload[:exception]&.first,
      exception_message: event.payload[:exception_object]&.message&.truncate(200)
    }.compact
  end

  # Log additional data for API endpoints
  config.lograge.custom_payload do |controller|
    payload = {}

    # Add user context if available
    if controller.respond_to?(:current_user) && controller.current_user
      payload[:user_id] = controller.current_user.id
    end

    # Add request metadata
    payload[:ip] = controller.request.remote_ip
    payload[:user_agent] = controller.request.user_agent
    payload[:request_id] = controller.request.request_id

    # Add session context for our app
    if controller.respond_to?(:params) && controller.params[:id] && controller.controller_name == "sessions"
      payload[:session_id] = controller.params[:id]
    end

    payload
  end

  # Don't log static assets and health checks
  config.lograge.ignore_actions = [ "ApplicationController#health_check" ]
  config.lograge.ignore_custom = lambda do |event|
    event.payload[:controller] == "Rails::HealthController" ||
    (event.payload[:path] && event.payload[:path].match(%r{^/assets/}))
  end
end
