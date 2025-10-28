# Security configurations and hardening

# Content Security Policy
if Rails.env.production? || Rails.env.staging?
  Rails.application.configure do
    config.content_security_policy do |policy|
      # Allow 'self' for most resources
      policy.default_src :self, :https
      
      # Allow specific script sources (Google Analytics requires unsafe-inline)
      policy.script_src :self, :unsafe_inline, 'https://cdn.jsdelivr.net', 'https://unpkg.com', 'https://www.googletagmanager.com', 'https://www.google-analytics.com', 'https://ssl.google-analytics.com', 'https://js.stripe.com'
      
      # Allow specific style sources
      policy.style_src :self, :unsafe_inline, 'https://fonts.googleapis.com'
      
      # Allow images from self, data URLs, and Google Analytics tracking pixels
      policy.img_src :self, :data, :https, 'https://www.google-analytics.com', 'https://www.googletagmanager.com'
      
      # Allow fonts from Google Fonts
      policy.font_src :self, 'https://fonts.gstatic.com'
      
      # Allow connections to specific hosts
      policy.connect_src :self, 'https://api.openai.com', 'https://api.deepgram.com', 'https://api.stripe.com', 'https://www.google-analytics.com', 'https://region1.google-analytics.com', 'https://analytics.google.com', 'https://stats.g.doubleclick.net', 'https://www.googletagmanager.com'
      
      # Media sources for audio/video
      policy.media_src :self, :blob
      
      # Object sources
      policy.object_src :none
      
      # Base URI
      policy.base_uri :self
      
      # Form action
      policy.form_action :self
      
      # Frame ancestors (prevent clickjacking)
      policy.frame_ancestors :none
      
      # Worker sources for web workers
      policy.worker_src :self, :blob
      
      # Child sources for frames and workers
      policy.child_src :self
      
      # Upgrade insecure requests
      policy.upgrade_insecure_requests true
      
      # Report violations (in production, set up a reporting endpoint)
      if Rails.env.production? && ENV['CSP_REPORT_URI'].present?
        policy.report_uri ENV['CSP_REPORT_URI']
      end
    end
    
    # CSP reporting only mode (remove in production after testing)
    if ENV['CSP_REPORT_ONLY'] == 'true'
      config.content_security_policy_report_only = true
    end
    
    # Disable nonce generation to ensure unsafe-inline works for Google Analytics
    # config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }

    # No nonce directives - relying on unsafe-inline for Google Analytics compatibility
    # config.content_security_policy_nonce_directives = %w[]
  end
end

# Security Headers
Rails.application.config.force_ssl = true if Rails.env.production? || Rails.env.staging?

# Configure secure session cookies
Rails.application.config.session_store :cookie_store,
  key: '_ai_talk_coach_session',
  domain: Rails.env.development? ? '.aitalkcoach.local' : '.aitalkcoach.com',
  secure: Rails.env.production? || Rails.env.staging?,
  httponly: true,
  same_site: :lax,
  expire_after: 24.hours

# Additional security headers middleware
class SecurityHeadersMiddleware
  def initialize(app)
    @app = app
  end
  
  def call(env)
    # Allow logout requests to pass through without modification
    if env['PATH_INFO'] == '/logout'
      return @app.call(env)
    end

    status, headers, response = @app.call(env)
    
    # Security headers
    headers['X-Frame-Options'] = 'DENY'
    headers['X-Content-Type-Options'] = 'nosniff'
    headers['X-XSS-Protection'] = '1; mode=block'
    headers['X-Download-Options'] = 'noopen'
    headers['X-Permitted-Cross-Domain-Policies'] = 'none'
    headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
    
    # Remove server information
    headers.delete('Server')
    headers.delete('X-Powered-By')
    
    # HSTS header (only in production with HTTPS)
    if (Rails.env.production? || Rails.env.staging?) && env['HTTPS'] == 'on'
      headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains; preload'
    end
    
    # Permissions Policy (formerly Feature Policy)
    headers['Permissions-Policy'] = [
      'geolocation=()',
      'midi=()',
      'sync-xhr=()',
      'microphone=(self)',  # Allow microphone for speech recording
      'camera=()',
      'magnetometer=()',
      'gyroscope=()',
      'fullscreen=(self)',
      'payment=(self)',  # Allow payment processing for Stripe
      'usb=()',
      'autoplay=()'
    ].join(', ')
    
    [status, headers, response]
  end
end

Rails.application.config.middleware.insert_before 0, SecurityHeadersMiddleware

# Parameter filtering for security
Rails.application.config.filter_parameters += [
  :password,
  :password_confirmation,
  :secret,
  :token,
  :api_key,
  :access_token,
  :auth_token,
  :authentication_token,
  :client_secret,
  :session,
  :cookie,
  :csrf_token,
  /private/i,
  /secret/i,
  /token/i,
  /key/i,
  /password/i
]

# Secure random configuration
SecureRandom.random_bytes(64) # Initialize the random number generator

# Rate limiting setup (if using Rack::Attack) - TEMPORARILY DISABLED
if false && defined?(Rack::Attack)
  Rack::Attack.throttle('requests by ip', limit: 300, period: 5.minutes) do |request|
    # Skip rate limiting for logout requests
    request.ip unless request.path == '/logout'
  end

  # Throttle login attempts
  Rack::Attack.throttle('login attempts by ip', limit: 5, period: 20.seconds) do |request|
    request.ip if request.path == '/login' && request.post?
  end
  
  # Throttle API requests
  Rack::Attack.throttle('api requests by ip', limit: 100, period: 1.hour) do |request|
    request.ip if request.path.start_with?('/api/')
  end
  
  # Block requests with suspicious patterns
  Rack::Attack.blocklist('block suspicious requests') do |request|
    # Block SQL injection attempts
    CGI.unescape(request.query_string) =~ /(\bunion\b|\bselect\b|\binsert\b|\bdelete\b|\bdrop\b)/i ||
    # Block XSS attempts
    CGI.unescape(request.query_string) =~ /<script/i ||
    # Block path traversal attempts
    request.path.include?('../') ||
    request.path.include?('..\\')
  end
  
  # Exponential backoff for repeated violations
  Rack::Attack.blocklist('block repeat offenders') do |request|
    Rack::Attack::Allow2Ban.filter(request.ip, maxretry: 5, findtime: 10.minutes, bantime: 1.hour) do
      # Return true if this IP has been rate limited recently
      Rails.cache.read("rate_limit_violations:#{request.ip}").to_i > 3
    end
  end
  
  # Track rate limit violations
  ActiveSupport::Notifications.subscribe('rack.attack') do |name, start, finish, request_id, payload|
    if payload[:request].env['rack.attack.matched']
      ip = payload[:request].ip
      Rails.cache.write("rate_limit_violations:#{ip}", 
                       Rails.cache.read("rate_limit_violations:#{ip}").to_i + 1, 
                       expires_in: 1.hour)
      
      Rails.logger.warn "Rate limit exceeded for IP: #{ip} on path: #{payload[:request].path}"
      
      # Report to monitoring if available
      if defined?(Monitoring::ErrorReporter)
        Monitoring::ErrorReporter.report_security_event(
          'rate_limit_violation',
          {
            ip: ip,
            path: payload[:request].path,
            user_agent: payload[:request].user_agent&.truncate(100)
          }
        )
      end
    end
  end
end

# Sensitive data masking for logs
if defined?(Lograge)
  Rails.application.configure do
    config.lograge.custom_payload do |controller|
      payload = {}
      
      # Add security context but mask sensitive data
      payload[:ip] = controller.request.remote_ip
      payload[:user_agent] = controller.request.user_agent&.truncate(100)
      
      # Add user context if available (but not sensitive data)
      if controller.respond_to?(:current_user) && controller.current_user
        payload[:user_id] = controller.current_user.id
      end
      
      # Mask sensitive parameters
      if controller.params.present?
        masked_params = controller.params.except('controller', 'action', 'format', 'authenticity_token')
                                         .to_unsafe_h
                                         .transform_values do |value|
          if value.to_s.length > 100
            "[LARGE_VALUE:#{value.to_s.bytesize}_bytes]"
          elsif value.to_s.match?(/password|secret|token|key/i)
            "[FILTERED]"
          else
            value.to_s.truncate(50)
          end
        end
        payload[:params] = masked_params.to_s.truncate(200) if masked_params.any?
      end
      
      payload
    end
  end
end

# Database security configurations
if Rails.env.production?
  # Enable SQL query logging for suspicious patterns
  ActiveSupport::Notifications.subscribe('sql.active_record') do |name, start, finish, id, payload|
    sql = payload[:sql]
    
    # Log suspicious SQL patterns
    if sql.match?(/(\bDROP\b|\bDELETE\b.*\bFROM\b.*(?!WHERE)|\bUPDATE\b.*(?!WHERE))/i)
      Rails.logger.warn "Potentially dangerous SQL query: #{sql.truncate(100)}"
      
      if defined?(Monitoring::ErrorReporter)
        Monitoring::ErrorReporter.report_security_event(
          'suspicious_sql_query',
          { sql: sql.truncate(200), duration: (finish - start) * 1000 }
        )
      end
    end
    
    # Log slow queries that might indicate SQL injection attempts
    duration = (finish - start) * 1000
    if duration > 5000 && sql.length > 500
      Rails.logger.warn "Slow complex query detected: #{duration.round(2)}ms - #{sql.truncate(100)}"
    end
  end
end

# File upload security
if defined?(ActiveStorage)
  # Configure allowed file types for uploads
  Rails.application.config.active_storage.content_types_allowed_inline = %w[
    image/png
    image/jpeg
    image/gif
    image/webp
    audio/mpeg
    audio/wav
    audio/webm
    video/mp4
    video/webm
  ]
  
  # Configure content types to serve as attachments (force download)
  Rails.application.config.active_storage.content_types_to_serve_as_binary = %w[
    application/javascript
    application/x-javascript
    text/javascript
    text/html
    text/xml
    application/xml
  ]
  
  # File size limits (configured via environment)
  Rails.application.config.active_storage.variant_processor = :mini_magick
end

Rails.logger.info "Security hardening configurations loaded for #{Rails.env} environment"