Sentry.init do |config|
  config.dsn = ENV['SENTRY_DSN']
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
  
  # Set tracesSampleRate to 1.0 to capture 100% of the transactions for tracing.
  # We recommend adjusting this value in production.
  config.traces_sample_rate = ENV.fetch('SENTRY_TRACES_SAMPLE_RATE', 0.1).to_f
  
  # Set profiles_sample_rate to 1.0 to profile 100% of sampled transactions.
  # We recommend adjusting this value in production.
  config.profiles_sample_rate = ENV.fetch('SENTRY_PROFILES_SAMPLE_RATE', 0.1).to_f
  
  config.environment = Rails.env
  config.release = ENV['SENTRY_RELEASE'] || 'ai-talk-coach@dev'
  
  # Don't send errors in development/test unless explicitly enabled
  config.enabled_environments = %w[production staging] + (ENV['SENTRY_ENABLED'] == 'true' ? [Rails.env] : [])
  
  # Filter out sensitive data
  config.excluded_exceptions += [
    'ActionController::RoutingError',
    'ActiveRecord::RecordNotFound',
    'ActionController::InvalidAuthenticityToken',
    'CGI::Session::CookieStore::TamperedWithCookie',
    'ActionController::InvalidCrossOriginRequest',
    'ActionDispatch::RemoteIp::IpSpoofAttackError',
    'ActionController::BadRequest',
    'ActionController::UnknownFormat'
  ]
  
  # Performance monitoring
  config.enable_tracing = true
  
  # Custom error context
  config.before_send = lambda do |event, hint|
    # Add custom tags
    event.tags[:component] = 'ai_talk_coach'
    
    # Add request context
    if event.request
      event.tags[:request_method] = event.request[:method]
      event.tags[:request_url] = event.request[:url]&.gsub(/\?.*/, '') # Remove query params for privacy
    end
    
    # Add user context (without PII)
    if event.user && event.user[:id]
      event.user = { id: event.user[:id] }
    end
    
    event
  end
end