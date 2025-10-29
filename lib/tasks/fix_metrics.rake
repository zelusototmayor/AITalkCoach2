namespace :metrics do
  desc "Fix sessions with incorrect overall_score calculations (where overall_score > 1)"
  task fix_overall_scores: :environment do
    puts "Finding sessions with incorrect overall_score values..."

    # Find sessions where overall_score is stored as percentage instead of decimal
    affected_sessions = Session.where(completed: true)
                              .where("analysis_json IS NOT NULL")
                              .select do |session|
      overall_score = session.analysis_data&.dig("overall_score")
      overall_score && overall_score.to_f > 1.0
    end

    puts "Found #{affected_sessions.count} sessions to fix"

    fixed_count = 0
    error_count = 0

    affected_sessions.each do |session|
      begin
        # Reprocess the metrics using the stored transcript data
        if session.analysis_data["transcript"].present? && session.analysis_data["metrics"].present?
          # Extract the words data needed for metrics calculation
          words = session.analysis_data.dig("metrics", "basic_metrics", "word_count") ?
                    session.analysis_data["words"] : []

          # Skip if we don't have the necessary data
          if words.blank?
            puts "  Skipping session #{session.id} - missing word timing data"
            error_count += 1
            next
          end

          # Recalculate metrics
          transcript_data = {
            transcript: session.analysis_data["transcript"],
            words: words,
            metadata: session.analysis_data.dig("metrics", "basic_metrics") || {}
          }

          metrics_service = Analysis::Metrics.new(transcript_data, session.issues.to_a)
          new_metrics = metrics_service.calculate_all_metrics

          # Update only the overall_scores section
          session.analysis_data["overall_score"] = new_metrics[:overall_scores][:overall_score]
          session.analysis_data["component_scores"] = new_metrics[:overall_scores][:component_scores]
          session.analysis_data["grade"] = new_metrics[:overall_scores][:grade]

          # Save the updated data
          session.save!

          puts "  ✓ Fixed session #{session.id}: #{session.analysis_data['overall_score']} (was: #{session.analysis_data['overall_score']})"
          fixed_count += 1
        else
          puts "  Skipping session #{session.id} - missing transcript or metrics data"
          error_count += 1
        end
      rescue => e
        puts "  ✗ Error fixing session #{session.id}: #{e.message}"
        error_count += 1
      end
    end

    puts "\nDone!"
    puts "Fixed: #{fixed_count}"
    puts "Errors: #{error_count}"
  end

  desc "Reprocess a specific session's metrics"
  task :reprocess_session, [ :session_id ] => :environment do |t, args|
    session_id = args[:session_id]

    unless session_id
      puts "Usage: rake metrics:reprocess_session[SESSION_ID]"
      exit 1
    end

    session = Session.find(session_id)

    puts "Reprocessing session #{session.id}..."
    puts "Old overall_score: #{session.analysis_data['overall_score']}"

    # Queue the job to reprocess
    Sessions::ProcessJob.perform_now(session.id)

    session.reload
    puts "New overall_score: #{session.analysis_data['overall_score']}"
    puts "Done!"
  end
end
