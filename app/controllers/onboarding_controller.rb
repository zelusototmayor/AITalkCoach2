class OnboardingController < ApplicationController
  before_action :require_login
  skip_before_action :require_onboarding
  before_action :redirect_if_completed, except: [:complete]

  # Screen 1: Why communication matters (informational page)
  def welcome
    # No form - just informational content with CTA to continue
  end

  # Screen 2: Speaking goals
  def profile
    if request.post?
      # Handle array of speaking goals
      goals = params[:speaking_goals]&.compact_blank || []

      if goals.empty?
        flash.now[:alert] = "Please select at least one speaking goal"
        render :profile, status: :unprocessable_content
        return
      end

      if current_user.update(speaking_goal: goals)
        redirect_to onboarding_demographics_path
      else
        flash.now[:alert] = "Unable to save your goals"
        render :profile, status: :unprocessable_content
      end
    end
    # GET request - render form
  end

  # Screen 3: Style + demographics + pronouns
  def demographics
    if request.post?
      demographics_params = params.permit(:speaking_style, :age_range, :profession, :preferred_pronouns)

      # Validate required fields
      if demographics_params[:speaking_style].blank? || demographics_params[:age_range].blank?
        flash.now[:alert] = "Please complete all required fields"
        render :demographics, status: :unprocessable_content
        return
      end

      if current_user.update(demographics_params)
        redirect_to onboarding_test_path
      else
        flash.now[:alert] = "Unable to save your information"
        render :demographics, status: :unprocessable_content
      end
    end
    # GET request - render form
  end

  # Screen 4: 30-second test (or show demo results if available)
  def test
    if request.get?
      # Check if user explicitly wants to re-record by clearing previous session
      if params[:new_recording] == 'true'
        # Clear previous demo session
        current_user.update(onboarding_demo_session_id: nil) if current_user.onboarding_demo_session_id.present?
        cookies.delete(:demo_trial_token)
        @demo_completed = false
        @trial_session = nil
      else
        # Check for demo session from cookie
        demo_token = cookies[:demo_trial_token]
        if demo_token
          @trial_session = TrialSession.find_by(token: demo_token, created_at: 1.hour.ago..)
          if @trial_session && @trial_session.completed?
            # Link demo session to user account
            current_user.update(onboarding_demo_session_id: @trial_session.id)
            @demo_completed = true
          end
        end
      end
    elsif request.post?
      # Handle fresh test recording or skip
      if params[:skipped] == 'true'
        redirect_to onboarding_pricing_path(skipped: true)
      elsif params[:audio_file].present? && params[:trial_recording] == 'true'
        # Handle trial recording upload
        begin
          trial_session = TrialSession.create!(
            title: "Onboarding Test",
            language: "en",
            media_kind: "audio",
            target_seconds: 30,
            processing_state: "pending"
          )

          # Store the audio file (note: it's media_files plural)
          trial_session.media_files.attach(params[:audio_file])

          # Process the trial session asynchronously using TrialProcessJob
          Sessions::TrialProcessJob.perform_later(trial_session.token)

          # Link to user and save token
          current_user.update(onboarding_demo_session_id: trial_session.id)
          cookies[:demo_trial_token] = { value: trial_session.token, expires: 1.hour.from_now }

          # Return JSON for AJAX submission - redirect to waiting page
          render json: {
            success: true,
            message: 'Recording uploaded successfully',
            trial_token: trial_session.token,
            redirect_url: onboarding_waiting_path
          }
        rescue => e
          Rails.logger.error "Onboarding trial recording error: #{e.message}"
          render json: {
            success: false,
            message: 'Failed to process recording. Please try again.',
            errors: [e.message]
          }, status: :unprocessable_entity
        end
      else
        redirect_to onboarding_pricing_path
      end
    end
  end

  # Screen 4.25: Waiting for analysis to complete
  def waiting
    # Find the trial session linked to this user
    if current_user.onboarding_demo_session_id.present?
      @trial_session = TrialSession.find_by(id: current_user.onboarding_demo_session_id)

      Rails.logger.info "Onboarding waiting: trial_session_id=#{current_user.onboarding_demo_session_id}, found=#{@trial_session.present?}, completed=#{@trial_session&.completed?}, state=#{@trial_session&.processing_state}"

      # If no trial session, redirect to test
      if @trial_session.nil?
        Rails.logger.warn "Onboarding waiting: Trial session not found, redirecting to test"
        redirect_to onboarding_test_path
        return
      end

      # If already completed, redirect to report
      if @trial_session.completed?
        Rails.logger.info "Onboarding waiting: Trial session already completed, redirecting to report"
        redirect_to onboarding_report_path
        return
      end

      # Otherwise, show waiting page with polling
      Rails.logger.info "Onboarding waiting: Showing waiting page for trial session #{@trial_session.id}"
    else
      # No trial session, redirect to test
      Rails.logger.warn "Onboarding waiting: No trial session ID on user, redirecting to test"
      redirect_to onboarding_test_path
    end
  end

  # Screen 4.5: Show report results (if trial session was completed)
  def report
    # Find the trial session linked to this user
    if current_user.onboarding_demo_session_id.present?
      @trial_session = TrialSession.find_by(id: current_user.onboarding_demo_session_id)

      Rails.logger.info "Onboarding report: trial_session_id=#{current_user.onboarding_demo_session_id}, found=#{@trial_session.present?}, completed=#{@trial_session&.completed?}"

      # If no trial session or not completed, redirect to pricing
      if @trial_session.nil?
        Rails.logger.warn "Onboarding report: Trial session not found, redirecting to pricing"
        redirect_to onboarding_pricing_path
        return
      elsif !@trial_session.completed?
        Rails.logger.warn "Onboarding report: Trial session not completed (state: #{@trial_session.processing_state}), redirecting to pricing"
        redirect_to onboarding_pricing_path
        return
      end

      Rails.logger.info "Onboarding report: Showing report for trial session #{@trial_session.id}"
    else
      # No trial session, skip to pricing
      Rails.logger.warn "Onboarding report: No trial session ID on user, redirecting to pricing"
      redirect_to onboarding_pricing_path
    end
  end

  # Screen 5: Pricing & payment collection
  def pricing
    if request.get?
      # Create Stripe SetupIntent for payment method collection
      setup_stripe_customer

      @setup_intent = ::Stripe::SetupIntent.create(
        customer: current_user.stripe_customer_id,
        payment_method_types: ['card']
      )
    elsif request.post?
      # Verify SetupIntent and save payment method
      setup_intent_id = params[:setup_intent_id]
      selected_plan = params[:selected_plan] # 'monthly' or 'yearly'

      begin
        # Verify the SetupIntent with Stripe
        setup_intent = ::Stripe::SetupIntent.retrieve(setup_intent_id)

        if setup_intent.status == 'succeeded'
          # Save payment method to customer
          payment_method = setup_intent.payment_method

          ::Stripe::PaymentMethod.attach(
            payment_method,
            { customer: current_user.stripe_customer_id }
          )

          # Set as default payment method
          ::Stripe::Customer.update(
            current_user.stripe_customer_id,
            invoice_settings: { default_payment_method: payment_method }
          )

          # Update user with selected plan and payment method (but don't charge yet)
          current_user.update!(
            subscription_plan: selected_plan,
            stripe_payment_method_id: payment_method
          )

          # Redirect to complete action to finalize onboarding and activate trial
          redirect_to onboarding_complete_path
        else
          flash[:alert] = "Payment method setup failed. Please try again."
          redirect_to onboarding_pricing_path
        end
      rescue ::Stripe::StripeError => e
        Rails.logger.error "Stripe error in onboarding: #{e.message}"
        flash[:alert] = "Payment error: #{e.message}"
        redirect_to onboarding_pricing_path
      end
    end
  end

  # Finalize onboarding
  def complete
    current_user.update!(
      onboarding_completed_at: Time.current,
      trial_starts_at: Time.current,
      trial_expires_at: 24.hours.from_now
    )

    # Migrate trial session to full session if it exists and is completed
    if current_user.onboarding_demo_session_id.present?
      trial_session = TrialSession.find_by(id: current_user.onboarding_demo_session_id)

      if trial_session&.completed?
        begin
          migrator = TrialSessionMigrator.new(trial_session.token, current_user)
          migrated_session = migrator.migrate!
          Rails.logger.info "Successfully migrated onboarding trial session #{trial_session.id} to session #{migrated_session.id} for user #{current_user.id}"
        rescue => e
          # Log error but don't fail onboarding
          Rails.logger.error "Failed to migrate onboarding trial session: #{e.message}"
        end
      else
        Rails.logger.warn "Trial session #{trial_session&.id} not completed, skipping migration"
      end
    end

    # Send welcome email
    OnboardingMailer.welcome(current_user).deliver_later

    redirect_to app_root_path, notice: "Welcome to AI Talk Coach! Your free trial is active. Practice daily to keep access free."
  end

  private

  def redirect_if_completed
    if current_user.onboarding_completed?
      redirect_to app_root_path, notice: "You've already completed onboarding"
    end
  end

  def setup_stripe_customer
    return if current_user.stripe_customer_id.present?

    # Create Stripe customer if doesn't exist
    current_user.get_or_create_stripe_customer
  end
end
