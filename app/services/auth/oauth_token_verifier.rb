module Auth
  class OauthTokenVerifier
    class VerificationError < StandardError; end

    GOOGLE_TOKEN_INFO_URL = "https://oauth2.googleapis.com/tokeninfo".freeze
    APPLE_KEYS_URL = "https://appleid.apple.com/auth/keys".freeze

    class << self
      # Verify Google ID token and extract user info
      # @param id_token [String] The Google ID token from client
      # @param client_id [String] Optional client ID to verify against (defaults to env)
      # @return [Hash] { email:, name:, google_uid:, email_verified: }
      def verify_google(id_token, client_id: nil)
        raise VerificationError, "ID token is required" if id_token.blank?

        # Use Google's tokeninfo endpoint for verification
        # This is simpler and more reliable than manual JWT verification
        response = Net::HTTP.get_response(
          URI("#{GOOGLE_TOKEN_INFO_URL}?id_token=#{CGI.escape(id_token)}")
        )

        unless response.is_a?(Net::HTTPSuccess)
          Rails.logger.error "Google token verification failed: #{response.body}"
          raise VerificationError, "Invalid Google ID token"
        end

        payload = JSON.parse(response.body)

        # Verify the audience (client ID) matches
        allowed_client_ids = [
          client_id,
          ENV["GOOGLE_CLIENT_ID"],
          ENV["GOOGLE_IOS_CLIENT_ID"]
        ].compact

        unless allowed_client_ids.include?(payload["aud"])
          Rails.logger.error "Google token audience mismatch: #{payload['aud']}"
          raise VerificationError, "Token was not issued for this application"
        end

        # Verify email is verified
        unless payload["email_verified"] == "true" || payload["email_verified"] == true
          raise VerificationError, "Email not verified with Google"
        end

        {
          email: payload["email"],
          name: payload["name"],
          google_uid: payload["sub"],
          email_verified: true
        }
      rescue JSON::ParserError => e
        Rails.logger.error "Failed to parse Google token response: #{e.message}"
        raise VerificationError, "Invalid response from Google"
      rescue StandardError => e
        raise e if e.is_a?(VerificationError)
        Rails.logger.error "Google token verification error: #{e.message}"
        raise VerificationError, "Failed to verify Google token"
      end

      # Verify Apple ID token and extract user info
      # @param id_token [String] The Apple identity token from client
      # @param client_id [String] Optional client ID to verify against
      # @return [Hash] { email:, apple_uid:, email_hidden: }
      def verify_apple(id_token, client_id: nil)
        raise VerificationError, "ID token is required" if id_token.blank?

        # Fetch Apple's public keys
        keys = fetch_apple_public_keys

        # Decode and verify the JWT
        decoded_token = decode_apple_jwt(id_token, keys)

        payload = decoded_token.first
        header = decoded_token.last

        # Verify issuer
        unless payload["iss"] == "https://appleid.apple.com"
          raise VerificationError, "Invalid token issuer"
        end

        # Verify audience (client ID)
        allowed_client_ids = [
          client_id,
          ENV["APPLE_CLIENT_ID"],
          ENV["APPLE_BUNDLE_ID"]
        ].compact

        unless allowed_client_ids.include?(payload["aud"])
          Rails.logger.error "Apple token audience mismatch: #{payload['aud']}"
          raise VerificationError, "Token was not issued for this application"
        end

        # Verify token hasn't expired
        if payload["exp"] && Time.at(payload["exp"]) < Time.current
          raise VerificationError, "Token has expired"
        end

        # Extract email info
        # Apple may hide email - check for private relay domain
        email = payload["email"]
        email_hidden = email&.include?("privaterelay.appleid.com") || false

        {
          email: email,
          apple_uid: payload["sub"],
          email_hidden: email_hidden
        }
      rescue JWT::DecodeError => e
        Rails.logger.error "Apple JWT decode error: #{e.message}"
        raise VerificationError, "Invalid Apple ID token"
      rescue StandardError => e
        raise e if e.is_a?(VerificationError)
        Rails.logger.error "Apple token verification error: #{e.message}"
        raise VerificationError, "Failed to verify Apple token"
      end

      private

      def fetch_apple_public_keys
        response = Net::HTTP.get_response(URI(APPLE_KEYS_URL))

        unless response.is_a?(Net::HTTPSuccess)
          raise VerificationError, "Failed to fetch Apple public keys"
        end

        JSON.parse(response.body)["keys"]
      rescue JSON::ParserError
        raise VerificationError, "Invalid response from Apple"
      end

      def decode_apple_jwt(id_token, keys)
        # Get the key ID from the token header
        header = JWT.decode(id_token, nil, false).last
        kid = header["kid"]

        # Find the matching key
        key_data = keys.find { |k| k["kid"] == kid }
        raise VerificationError, "No matching key found" unless key_data

        # Build the public key from JWK
        jwk = JWT::JWK.new(key_data)

        # Decode and verify the token
        JWT.decode(
          id_token,
          jwk.public_key,
          true,
          {
            algorithm: "RS256",
            verify_iat: true
          }
        )
      end
    end
  end
end
