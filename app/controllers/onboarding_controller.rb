class OnboardingController < ApplicationController
  before_action :require_login
  skip_before_action :require_onboarding
  before_action :redirect_lifetime_users
  before_action :redirect_if_completed, except: [ :complete ]

  # Screen 0: Splash screen with animated logo
  def splash
    # Auto-advances to welcome page after 2.5 seconds
  end

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
        redirect_to onboarding_motivation_path
      else
        flash.now[:alert] = "Unable to save your goals"
        render :profile, status: :unprocessable_content
      end
    end
    # GET request - render form
  end

  # Screen 2.5: Motivation page
  def motivation
    # Informational page - auto-advances or has continue button
  end

  # Screen 3: Metrics intro - explain key metrics
  def metrics_intro
    # Informational page - introduces clarity, filler words, speaking pace
  end

  # Screen 4: Overall score explanation
  def overall_score
    # Informational page - explains how overall score is calculated
  end

  # Screen 5: Coach intro - AI coaching features
  def coach_intro
    # Informational page - introduces AI coach features
  end

  # Screen 6: Progress tracking intro
  def progress_intro
    # Informational page - explains progress tracking capabilities
  end

  # Screen 7: Style + demographics + pronouns
  def demographics
    if request.post?
      demographics_params = params.permit(:speaking_style, :age_range, :profession, :preferred_pronouns, :preferred_language)

      # Validate required fields
      if demographics_params[:speaking_style].blank? || demographics_params[:age_range].blank? || demographics_params[:preferred_language].blank?
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
      if params[:new_recording] == "true"
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
      if params[:skipped] == "true"
        # Create a mock trial session for preview
        create_mock_trial_session_for_user
        redirect_to onboarding_report_path
      elsif params[:audio_file].present? && params[:trial_recording] == "true"
        # Handle trial recording upload
        begin
          trial_session = TrialSession.create!(
            title: "Onboarding Test",
            language: current_user.preferred_language || "en",
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

          # Return JSON for AJAX submission - redirect to report page
          render json: {
            success: true,
            message: "Recording uploaded successfully",
            trial_token: trial_session.token,
            redirect_url: onboarding_report_path
          }
        rescue => e
          Rails.logger.error "Onboarding trial recording error: #{e.message}"
          render json: {
            success: false,
            message: "Failed to process recording. Please try again.",
            errors: [ e.message ]
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

  # Screen 4.5: Show report results (with polling if not yet completed)
  def report
    # Find the trial session linked to this user
    if current_user.onboarding_demo_session_id.present?
      @trial_session = TrialSession.find_by(id: current_user.onboarding_demo_session_id)

      Rails.logger.info "Onboarding report: trial_session_id=#{current_user.onboarding_demo_session_id}, found=#{@trial_session.present?}, completed=#{@trial_session&.completed?}"

      # If no trial session, redirect to pricing
      if @trial_session.nil?
        Rails.logger.warn "Onboarding report: Trial session not found, redirecting to pricing"
        redirect_to onboarding_pricing_path
        return
      end

      # Allow rendering even if not completed - view will handle polling
      Rails.logger.info "Onboarding report: Showing report for trial session #{@trial_session.id}, state: #{@trial_session.processing_state}"
    else
      # No trial session, skip to pricing
      Rails.logger.warn "Onboarding report: No trial session ID on user, redirecting to pricing"
      redirect_to onboarding_pricing_path
    end
  end

  # Screen 4.75: Cinematic "Free Forever" animation
  def cinematic
    # Set aggressive cache-control headers to prevent caching
    response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate, private, max-age=0"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "0"
  end

  # Screen 5: Pricing & payment collection
  def pricing
    if request.get?
      # Skip Stripe setup in development mode
      if Rails.env.development?
        @setup_intent = OpenStruct.new(client_secret: "mock_client_secret_for_development")
        return
      end

      # Create Stripe SetupIntent for payment method collection
      setup_stripe_customer

      @setup_intent = ::Stripe::SetupIntent.create(
        customer: current_user.stripe_customer_id,
        payment_method_types: [ "card" ]
      )
    elsif request.post?
      # Skip Stripe in development mode
      if Rails.env.development?
        selected_plan = params[:selected_plan] || 'monthly'
        promo_code = params[:promo_code]

        current_user.update!(
          subscription_plan: selected_plan,
          stripe_payment_method_id: 'mock_payment_method_for_development',
          promo_code: promo_code
        )
        redirect_to onboarding_complete_path
        return
      end

      # Verify SetupIntent and save payment method
      setup_intent_id = params[:setup_intent_id]
      selected_plan = params[:selected_plan] # 'monthly' or 'yearly'
      promo_code = params[:promo_code]

      begin
        # Verify the SetupIntent with Stripe
        setup_intent = ::Stripe::SetupIntent.retrieve(setup_intent_id)

        if setup_intent.status == "succeeded"
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
            stripe_payment_method_id: payment_method,
            promo_code: promo_code
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
    # FOR TESTING: Grant extended trial (30 days) until Stripe is integrated
    # TODO: Change this to 24.hours.from_now once payment is integrated
    current_user.update!(
      onboarding_completed_at: Time.current,
      trial_starts_at: Time.current,
      trial_expires_at: 30.days.from_now  # Extended trial for testing
    )

    # Migrate trial session to full session if it exists, is completed, and is not mock data
    if current_user.onboarding_demo_session_id.present?
      trial_session = TrialSession.find_by(id: current_user.onboarding_demo_session_id)

      if trial_session&.completed? && !trial_session.is_mock
        begin
          migrator = TrialSessionMigrator.new(trial_session.token, current_user)
          migrated_session = migrator.migrate!
          Rails.logger.info "Successfully migrated onboarding trial session #{trial_session.id} to session #{migrated_session.id} for user #{current_user.id}"
        rescue => e
          # Log error but don't fail onboarding
          Rails.logger.error "Failed to migrate onboarding trial session: #{e.message}"
        end
      else
        if trial_session&.is_mock
          Rails.logger.info "Trial session #{trial_session.id} is mock data, skipping migration"
        else
          Rails.logger.warn "Trial session #{trial_session&.id} not completed, skipping migration"
        end
      end
    end

    # Send welcome email
    OnboardingMailer.welcome(current_user).deliver_later

    respond_to do |format|
      format.html { redirect_to app_root_path, notice: "Welcome to AI Talk Coach! Your free trial is active. Practice daily to keep access free." }
      format.json {
        render json: {
          success: true,
          user: {
            id: current_user.id,
            name: current_user.name,
            email: current_user.email,
            onboarding_completed: true,
            subscription_status: current_user.subscription_status,
            trial_expires_at: current_user.trial_expires_at
          },
          message: "Onboarding completed successfully"
        }
      }
    end
  end

  private

  def redirect_if_completed
    if current_user.onboarding_completed?
      redirect_to app_root_path, notice: "You've already completed onboarding"
    end
  end

  def redirect_lifetime_users
    if current_user.subscription_lifetime?
      redirect_to practice_path, notice: "Welcome! You have lifetime access."
    end
  end

  def setup_stripe_customer
    return if current_user.stripe_customer_id.present?

    # Create Stripe customer if doesn't exist
    current_user.get_or_create_stripe_customer
  end

  def create_mock_trial_session_for_user
    # Create a mock trial session with realistic sample data
    mock_transcript = "Well, last week was actually pretty interesting. I had a chance to, um, catch up with an old friend I hadn't seen in years. We went to this new coffee shop downtown, and it was really nice to just, you know, reconnect and talk about old times. The weather was perfect too, which made the whole experience even better."

    trial_session = TrialSession.create!(
      title: "Sample Demo Session (Mock Data)",
      language: "en",
      media_kind: "audio",
      target_seconds: 30,
      duration_ms: 30000,
      processing_state: "completed",
      completed: true,
      processed_at: Time.current,
      is_mock: true,
      analysis_data: {
        transcript: mock_transcript,
        wpm: 165,
        filler_count: 3  # "um" and two "you know"s
      }
    )

    # Link to user
    current_user.update(onboarding_demo_session_id: trial_session.id)
    trial_session
  end
end
