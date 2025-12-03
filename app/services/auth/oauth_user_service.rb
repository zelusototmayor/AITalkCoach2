module Auth
  class OauthUserService
    class OauthError < StandardError; end

    class << self
      # Find or create a user from OAuth credentials
      # Implements auto-linking: if a user with the same email exists, link the OAuth UID
      #
      # @param provider [Symbol] :google or :apple
      # @param uid [String] The provider's unique user ID
      # @param email [String] User's email address
      # @param name [String] User's display name (optional, may not be provided by Apple)
      # @param email_hidden [Boolean] Whether email is hidden (Apple only)
      # @return [Hash] { user:, is_new_user:, was_linked: }
      def find_or_create_from_oauth(provider:, uid:, email:, name: nil, email_hidden: false)
        raise OauthError, "Provider is required" unless provider.in?([ :google, :apple ])
        raise OauthError, "UID is required" if uid.blank?

        uid_column = "#{provider}_uid"

        # Step 1: Try to find existing user by OAuth UID
        user = User.find_by(uid_column => uid)
        if user
          return { user: user, is_new_user: false, was_linked: false }
        end

        # Step 2: Try to find existing user by email (auto-link)
        if email.present? && !email_hidden
          user = User.find_by(email: email.downcase.strip)
          if user
            # Link OAuth to existing account
            user.update!(uid_column => uid, auth_provider: user.auth_provider || provider.to_s)
            Rails.logger.info "Linked #{provider} account (#{uid}) to existing user #{user.id}"
            return { user: user, is_new_user: false, was_linked: true }
          end
        end

        # Step 3: Create new user
        user = create_oauth_user(
          provider: provider,
          uid: uid,
          email: email,
          name: name
        )

        { user: user, is_new_user: true, was_linked: false }
      end

      private

      def create_oauth_user(provider:, uid:, email:, name:)
        uid_column = "#{provider}_uid"

        # Generate placeholder email if hidden (Apple)
        if email.blank?
          email = "#{provider}_#{uid}@placeholder.aitalkcoach.com"
        end

        # Generate name if not provided
        if name.blank?
          name = email.split("@").first.gsub(/[^a-zA-Z0-9]/, " ").titleize.truncate(50)
        end

        user = User.new(
          email: email.downcase.strip,
          name: name,
          uid_column => uid,
          auth_provider: provider.to_s,
          preferred_language: LanguageService.default_language,
          subscription_status: "free_trial",
          trial_starts_at: Time.current,
          trial_expires_at: 24.hours.from_now
        )

        # Skip password validation for OAuth users
        user.save!
        Rails.logger.info "Created new #{provider} user: #{user.id} (#{user.email})"

        user
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error "Failed to create OAuth user: #{e.message}"
        raise OauthError, "Failed to create account: #{e.record.errors.full_messages.join(', ')}"
      end
    end
  end
end
