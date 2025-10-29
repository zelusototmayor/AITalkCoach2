class TrialSessionMigrator
  class MigrationError < StandardError; end
  class TrialSessionNotFound < MigrationError; end
  class TrialSessionExpired < MigrationError; end
  class TrialSessionAlreadyMigrated < MigrationError; end

  def initialize(trial_token, user)
    @trial_token = trial_token
    @user = user
    @trial_session = nil
    @migrated_session = nil
  end

  def migrate!
    validate_inputs!
    find_and_validate_trial_session!

    ActiveRecord::Base.transaction do
      create_full_session!
      migrate_media_files!
      validate_migrated_session!
      migrate_analysis_data!
      mark_trial_as_migrated!
      queue_enhanced_processing!
    end

    @migrated_session
  rescue => e
    Rails.logger.error "Trial session migration failed: #{e.message}"
    raise MigrationError, "Failed to migrate trial session: #{e.message}"
  end

  private

  def validate_inputs!
    raise MigrationError, "Trial token cannot be blank" if @trial_token.blank?
    raise MigrationError, "User cannot be nil" if @user.nil?
  end

  def find_and_validate_trial_session!
    @trial_session = TrialSession.find_by(token: @trial_token)

    raise TrialSessionNotFound, "Trial session not found" unless @trial_session
    raise TrialSessionExpired, "Trial session has expired" if @trial_session.expired?

    # Check if already migrated by looking for existing session with same analysis data signature
    if already_migrated?
      raise TrialSessionAlreadyMigrated, "Trial session already migrated"
    end
  end

  def already_migrated?
    # Check if a session already exists for this user with the same timestamp and basic data
    return false unless @trial_session.analysis_data.present?

    trial_created_at = @trial_session.created_at
    trial_transcript = @trial_session.analysis_data["transcript"]

    return false if trial_transcript.blank?

    # Look for sessions created within 5 minutes of trial session
    # with the same transcript (first 100 characters to avoid exact duplicates)
    transcript_prefix = trial_transcript[0..99]

    @user.sessions.where(
      "sessions.created_at BETWEEN ? AND ?",
      trial_created_at - 5.minutes,
      trial_created_at + 5.minutes
    ).joins(:user).where(
      "sessions.analysis_json LIKE ?",
      "%#{transcript_prefix}%"
    ).exists?
  end

  def create_full_session!
    # Calculate appropriate target_seconds based on actual duration
    target_duration = calculate_target_seconds

    @migrated_session = @user.sessions.build(
      title: @trial_session.title,
      language: @trial_session.language,
      media_kind: @trial_session.media_kind,
      target_seconds: target_duration,
      processing_state: "pending",
      completed: false,
      minimum_duration_enforced: true,
      speech_context: "migrated_trial",
      duration_ms: @trial_session.duration_ms,
      created_at: @trial_session.created_at, # Preserve original timestamp
      updated_at: Time.current
    )

    # Skip validations initially since media files aren't attached yet
    unless @migrated_session.save(validate: false)
      raise MigrationError, "Failed to create session: #{@migrated_session.errors.full_messages.join(', ')}"
    end

    Rails.logger.info "Created migrated session #{@migrated_session.id} from trial #{@trial_token}"
  end

  def migrate_media_files!
    unless @trial_session.media_files.any?
      raise MigrationError, "Trial session has no media files to migrate"
    end

    @trial_session.media_files.each do |media_file|
      begin
        # Copy the media file to the new session by creating a new attachment from the blob
        @migrated_session.media_files.attach(media_file.blob)
      rescue => e
        raise MigrationError, "Failed to migrate media file #{media_file.filename}: #{e.message}"
      end
    end

    # Ensure media files are actually attached
    unless @migrated_session.media_files.any?
      raise MigrationError, "Media files failed to attach to migrated session"
    end

    Rails.logger.info "Successfully migrated #{@trial_session.media_files.count} media files"
  end

  def migrate_analysis_data!
    return unless @trial_session.analysis_data.present?

    # Enhance the basic trial data for full session
    enhanced_data = enhance_trial_analysis_data(@trial_session.analysis_data)

    @migrated_session.update!(
      analysis_data: enhanced_data,
      analysis_json: enhanced_data.to_json
    )

    Rails.logger.info "Migrated analysis data with enhancement"
  end

  def enhance_trial_analysis_data(trial_data)
    # Start with trial data and enhance for full session compatibility
    enhanced = trial_data.dup

    # Add full session fields that trial doesn't have
    enhanced.merge!(
      "migrated_from_trial" => true,
      "migration_timestamp" => Time.current.iso8601,
      "original_trial_token" => @trial_token,

      # Initialize fields that will be populated by full processing
      "clarity_score" => calculate_enhanced_clarity_score(trial_data),
      "fluency_score" => calculate_fluency_score(trial_data),
      "engagement_score" => calculate_engagement_score(trial_data),
      "pace_consistency" => calculate_pace_consistency(trial_data),
      "speech_to_silence_ratio" => 0.75, # Placeholder - will be calculated in full processing
      "overall_score" => calculate_overall_score(trial_data),

      # Enhanced metadata
      "processing_notes" => "Migrated from trial session - full analysis pending",
      "enhancement_status" => "pending"
    )

    enhanced
  end

  def calculate_enhanced_clarity_score(trial_data)
    # More sophisticated clarity calculation than trial's basic version
    filler_count = trial_data["filler_count"] || 0
    word_count = trial_data["word_count"] || 100
    duration = trial_data["duration_seconds"] || 30

    # Base score starts higher for migrated sessions
    base_score = 0.90

    # Penalties
    filler_penalty = (filler_count.to_f / word_count) * 0.3
    pace_penalty = 0

    wpm = trial_data["wpm"] || 150
    if wpm < 120 || wpm > 200
      pace_penalty = 0.1
    end

    final_score = base_score - filler_penalty - pace_penalty
    [ [ final_score, 0.0 ].max, 1.0 ].min
  end

  def calculate_fluency_score(trial_data)
    # Basic fluency based on available trial data
    wpm = trial_data["wpm"] || 150
    filler_count = trial_data["filler_count"] || 0
    word_count = trial_data["word_count"] || 100

    # Normalize WPM to 0-1 scale (ideal around 150)
    wpm_score = 1.0 - ((wpm - 150).abs / 150.0)
    wpm_score = [ [ wpm_score, 0.0 ].max, 1.0 ].min

    # Filler penalty
    filler_rate = filler_count.to_f / word_count
    filler_score = 1.0 - (filler_rate * 2.0)
    filler_score = [ [ filler_score, 0.0 ].max, 1.0 ].min

    # Combined fluency score
    ((wpm_score * 0.7) + (filler_score * 0.3)).round(3)
  end

  def calculate_engagement_score(trial_data)
    # Basic engagement estimation
    wpm = trial_data["wpm"] || 150
    word_count = trial_data["word_count"] || 100
    duration = trial_data["duration_seconds"] || 30

    # Engagement factors
    pace_factor = if wpm >= 130 && wpm <= 180
      1.0
    elsif wpm < 100 || wpm > 220
      0.6
    else
      0.8
    end

    # Length factor (longer speeches show more engagement)
    length_factor = if duration >= 25
      1.0
    elsif duration < 15
      0.7
    else
      0.85
    end

    # Complexity factor (more words per second of recording)
    complexity_factor = if word_count / duration > 2.3
      1.0
    else
      0.8
    end

    (pace_factor * length_factor * complexity_factor * 0.85).round(3)
  end

  def calculate_pace_consistency(trial_data)
    # Simplified pace consistency for trial data
    wpm = trial_data["wpm"] || 150
    ideal_wpm = 150.0

    deviation = (wpm - ideal_wpm).abs / ideal_wpm
    consistency = 1.0 - [ deviation, 1.0 ].min
    [ [ consistency, 0.0 ].max, 1.0 ].min.round(3)
  end

  def calculate_overall_score(trial_data)
    # Weighted combination of available scores
    clarity = calculate_enhanced_clarity_score(trial_data)
    fluency = calculate_fluency_score(trial_data)
    engagement = calculate_engagement_score(trial_data)
    pace = calculate_pace_consistency(trial_data)

    overall = (clarity * 0.3) + (fluency * 0.25) + (engagement * 0.25) + (pace * 0.2)
    overall.round(3)
  end

  def mark_trial_as_migrated!
    # Add migration metadata to trial session
    migration_data = @trial_session.analysis_data || {}
    migration_data.merge!(
      "migrated_to_session_id" => @migrated_session.id,
      "migrated_at" => Time.current.iso8601,
      "migration_status" => "completed"
    )

    @trial_session.update!(
      analysis_data: migration_data,
      updated_at: Time.current
    )
  end

  def validate_migrated_session!
    # Now that media files are attached, validate the session
    unless @migrated_session.valid?
      raise MigrationError, "Session validation failed after migration: #{@migrated_session.errors.full_messages.join(', ')}"
    end

    Rails.logger.info "Migrated session #{@migrated_session.id} passed validation"
  end

  def calculate_target_seconds
    # Map trial session's actual duration to the nearest valid preset duration
    # Valid durations: [30, 45, 60, 90, 120, 300]
    actual_duration = @trial_session.duration_seconds

    return 60 if actual_duration <= 0 # Default fallback

    valid_durations = [ 30, 45, 60, 90, 120, 300 ]

    # Find the closest valid duration
    closest_duration = valid_durations.min_by { |duration| (duration - actual_duration).abs }

    # If the actual duration is very close to a preset (within 5 seconds), use that preset
    # Otherwise, use the next higher preset to ensure the session meets the target
    if (closest_duration - actual_duration).abs <= 5
      closest_duration
    else
      # Use next higher duration to accommodate the full recording
      valid_durations.find { |d| d >= actual_duration } || 300
    end
  end

  def queue_enhanced_processing!
    # Queue the full processing job for enhanced analysis
    begin
      Sessions::ProcessJob.perform_later(@migrated_session.id)
      Rails.logger.info "Queued enhanced processing for migrated session #{@migrated_session.id}"
    rescue NotImplementedError => e
      # In test/development environments, the job queue might not support delayed jobs
      Rails.logger.warn "Could not queue enhanced processing job: #{e.message}"
      Rails.logger.info "Enhanced processing will need to be triggered manually for session #{@migrated_session.id}"
    end
  end
end
