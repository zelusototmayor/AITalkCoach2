# Redis configuration for JWT token blacklisting
require "redis"

# Initialize Redis client
$redis = Redis.new(
  url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"),
  timeout: 1,
  reconnect_attempts: 3
)

# Test Redis connection on boot (in development/production)
begin
  $redis.ping
  Rails.logger.info "Redis connected successfully for JWT blacklisting"
rescue Redis::CannotConnectError => e
  Rails.logger.warn "Redis connection failed: #{e.message}. JWT blacklisting will be disabled."
  $redis = nil
end
