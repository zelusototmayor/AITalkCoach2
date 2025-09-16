# Privacy Management Tasks

namespace :privacy do
  desc "Clean up expired audio files based on user privacy settings"
  task cleanup_audio: :environment do
    puts "Starting privacy-based audio cleanup..."
    puts "Timestamp: #{Time.current}"
    
    report = Privacy::AudioCleanupService.new.generate_cleanup_report
    
    puts "\n📊 CLEANUP REPORT"
    puts "="*50
    puts "Users processed: #{report[:users_processed]}"
    puts "Sessions processed: #{report[:sessions_processed]}"
    puts "Files deleted: #{report[:files_deleted]}"
    
    if report[:errors].any?
      puts "\n⚠️  ERRORS (#{report[:errors].count})"
      puts "-"*30
      report[:errors].each do |error|
        puts "Session #{error[:session_id]} (#{error[:user_email]}): #{error[:error]}"
      end
    end
    
    puts "\n📈 PRIVACY STATISTICS"
    puts "-"*30
    puts "Users with auto-delete enabled: #{report[:privacy_stats][:users_with_auto_delete]}"
    puts "Users with processed audio deletion: #{report[:privacy_stats][:users_with_processed_delete]}"
    puts "Average retention period: #{report[:privacy_stats][:average_retention_days]} days"
    
    puts "\n✅ Cleanup completed at #{Time.current}"
  end
  
  desc "Clean up processed audio files for completed sessions (if user preference allows)"
  task cleanup_processed: :environment do
    puts "Cleaning up processed audio files from completed sessions..."
    
    files_deleted = 0
    sessions_processed = 0
    
    User.where(delete_processed_audio: true).find_each do |user|
      user.sessions.where(completed: true).find_each do |session|
        sessions_processed += 1
        deleted = Privacy::AudioCleanupService.new.send(:cleanup_processed_audio_if_enabled, session)
        files_deleted += deleted if deleted
      end
    end
    
    puts "Sessions processed: #{sessions_processed}"
    puts "Files deleted: #{files_deleted}"
    puts "Completed at #{Time.current}"
  end
  
  desc "Show privacy statistics across all users"
  task stats: :environment do
    puts "🔐 PRIVACY STATISTICS"
    puts "="*50
    
    total_users = User.count
    users_with_auto_delete = User.where.not(auto_delete_audio_days: nil).count
    users_with_processed_delete = User.where(delete_processed_audio: true).count
    users_in_privacy_mode = User.where(privacy_mode: true).count
    
    puts "Total users: #{total_users}"
    puts "Users with auto-delete: #{users_with_auto_delete} (#{(users_with_auto_delete.to_f / total_users * 100).round(1)}%)"
    puts "Users with processed audio deletion: #{users_with_processed_delete} (#{(users_with_processed_delete.to_f / total_users * 100).round(1)}%)"
    puts "Users in privacy mode: #{users_in_privacy_mode} (#{(users_in_privacy_mode.to_f / total_users * 100).round(1)}%)"
    
    if users_with_auto_delete > 0
      retention_periods = User.where.not(auto_delete_audio_days: nil).group(:auto_delete_audio_days).count
      puts "\nRetention period distribution:"
      retention_periods.sort.each do |days, count|
        puts "  #{days} days: #{count} users"
      end
      
      avg_retention = User.where.not(auto_delete_audio_days: nil).average(:auto_delete_audio_days).to_f
      puts "Average retention period: #{avg_retention.round(1)} days"
    end
    
    # Audio file statistics
    total_sessions = Session.count
    sessions_with_audio = Session.joins(:media_files_attachments).distinct.count
    sessions_audio_deleted = Session.where("analysis_data->>'audio_deleted_for_privacy' = 'true'").count
    
    puts "\n📁 AUDIO FILE STATISTICS"
    puts "-"*30
    puts "Total sessions: #{total_sessions}"
    puts "Sessions with audio files: #{sessions_with_audio}"
    puts "Sessions with audio deleted for privacy: #{sessions_audio_deleted}"
    
    if total_sessions > 0
      audio_retention_rate = ((sessions_with_audio.to_f / total_sessions) * 100).round(1)
      puts "Audio retention rate: #{audio_retention_rate}%"
    end
  end
  
  desc "Purge all data for a specific user (GDPR compliance)"
  task :purge_user_data, [:email] => :environment do |t, args|
    email = args[:email]
    
    unless email
      puts "Usage: rake privacy:purge_user_data[user@example.com]"
      exit 1
    end
    
    user = User.find_by(email: email)
    unless user
      puts "❌ User with email '#{email}' not found"
      exit 1
    end
    
    puts "🗑️  PURGING ALL DATA FOR USER: #{email}"
    puts "="*50
    puts "⚠️  WARNING: This action cannot be undone!"
    
    # In a real app, you'd want additional confirmation here
    puts "Proceeding with data purge in 3 seconds..."
    sleep 3
    
    sessions_count = user.sessions.count
    issues_count = user.issues.count
    embeddings_count = user.user_issue_embeddings.count
    
    # Delete all audio files first
    user.sessions.find_each do |session|
      session.media_files.purge if session.media_files.attached?
    end
    
    # Delete user and all associated data (cascading deletes handle the rest)
    user.destroy!
    
    puts "✅ User data purged successfully"
    puts "Sessions deleted: #{sessions_count}"
    puts "Issues deleted: #{issues_count}"
    puts "Embeddings deleted: #{embeddings_count}"
    puts "Completed at #{Time.current}"
  end
  
  desc "Export user data for download (GDPR compliance)"
  task :export_user_data, [:email] => :environment do |t, args|
    email = args[:email]
    
    unless email
      puts "Usage: rake privacy:export_user_data[user@example.com]"
      exit 1
    end
    
    user = User.find_by(email: email)
    unless user
      puts "❌ User with email '#{email}' not found"
      exit 1
    end
    
    puts "📦 EXPORTING DATA FOR USER: #{email}"
    puts "="*50
    
    export_data = {
      user: {
        email: user.email,
        created_at: user.created_at,
        privacy_settings: {
          auto_delete_audio_days: user.auto_delete_audio_days,
          privacy_mode: user.privacy_mode,
          delete_processed_audio: user.delete_processed_audio
        }
      },
      sessions: user.sessions.map do |session|
        {
          id: session.id,
          title: session.title,
          language: session.language,
          duration_ms: session.duration_ms,
          created_at: session.created_at,
          completed: session.completed,
          analysis_data: session.analysis_data,
          media_files_count: session.media_files.count
        }
      end,
      issues: user.issues.map do |issue|
        {
          id: issue.id,
          session_id: issue.session_id,
          kind: issue.kind,
          category: issue.category,
          start_ms: issue.start_ms,
          end_ms: issue.end_ms,
          text: issue.text,
          coaching_note: issue.coaching_note,
          created_at: issue.created_at
        }
      end,
      embeddings: user.user_issue_embeddings.map do |embedding|
        {
          id: embedding.id,
          issue_category: embedding.issue_category,
          embedding_vector: embedding.embedding_vector,
          created_at: embedding.created_at
        }
      end,
      export_metadata: {
        generated_at: Time.current.iso8601,
        format_version: "1.0"
      }
    }
    
    filename = "user_data_export_#{email.parameterize}_#{Time.current.strftime('%Y%m%d_%H%M%S')}.json"
    filepath = Rails.root.join('tmp', filename)
    
    File.write(filepath, JSON.pretty_generate(export_data))
    
    puts "✅ Export completed successfully"
    puts "Sessions exported: #{export_data[:sessions].count}"
    puts "Issues exported: #{export_data[:issues].count}"
    puts "Embeddings exported: #{export_data[:embeddings].count}"
    puts "File saved to: #{filepath}"
    puts "File size: #{(File.size(filepath) / 1024.0 / 1024.0).round(2)} MB"
  end
end