# JWT token encoding/decoding utility
require 'jwt'

class JsonWebToken
  # Secret key for signing tokens - use Rails secret key base
  SECRET_KEY = Rails.application.credentials.secret_key_base || ENV["SECRET_KEY_BASE"]

  # Encode a payload into a JWT token
  # Default expiration is 24 hours
  def self.encode(payload, exp = 24.hours.from_now)
    # Add expiration to payload if not already set
    payload[:exp] = exp.to_i unless payload[:exp]

    # Add issued at timestamp
    payload[:iat] = Time.now.to_i

    # Add JWT ID for blacklisting support
    payload[:jti] = SecureRandom.uuid

    JWT.encode(payload, SECRET_KEY, 'HS256')
  end

  # Decode a JWT token and return the payload
  def self.decode(token)
    return nil if token.blank?

    body = JWT.decode(token, SECRET_KEY, true, algorithm: 'HS256')[0]

    # Check if token is blacklisted
    if $redis && body['jti']
      is_blacklisted = $redis.get("jwt_blacklist:#{body['jti']}")
      if is_blacklisted
        Rails.logger.info "Rejected blacklisted JWT: #{body['jti']}"
        return nil
      end
    end

    HashWithIndifferentAccess.new(body)
  rescue JWT::DecodeError, JWT::ExpiredSignature
    nil
  end
end