class PrivacySettingsController < ApplicationController
  before_action :set_user

  def show
    @user = @current_user
    @audio_file_stats = calculate_audio_file_stats
  end

  def update
    @user = @current_user

    if @user.update(privacy_params)
      # If user enabled immediate deletion of processed audio, trigger cleanup
      if params[:user][:delete_processed_audio] == '1'
        cleanup_processed_audio_async
      end

      redirect_to '/privacy_settings', notice: 'Privacy settings updated successfully.'
    else
      @audio_file_stats = calculate_audio_file_stats
      render :show, status: :unprocessable_content
    end
  end

  private

  def set_user
    @current_user = logged_in? ? current_user : User.find_by(email: 'guest@aitalkcoach.local')

    if @current_user.nil?
      redirect_to root_path, alert: 'User not found.'
    end
  end
  
  def privacy_params
    params.require(:user).permit(:auto_delete_audio_days, :privacy_mode, :delete_processed_audio)
  end
  
  def calculate_audio_file_stats
    user_sessions = @current_user.sessions
    all_sessions = user_sessions.includes(:media_files_attachments)
    
    {
      total_sessions: user_sessions.count,
      sessions_with_audio: user_sessions.joins(:media_files_attachments).distinct.count,
      sessions_audio_deleted: all_sessions.select { |s| s.analysis_data.present? && s.analysis_data['audio_deleted_for_privacy'] == true }.count,
      sessions_processed_deleted: all_sessions.select { |s| s.analysis_data.present? && s.analysis_data['processed_audio_deleted'] == true }.count,
      oldest_session: user_sessions.minimum(:created_at),
      newest_session: user_sessions.maximum(:created_at)
    }
  end
  
  def cleanup_processed_audio_async
    # In a real application, this would be enqueued as a background job
    # For now, we'll just run it inline for simplicity
    deleted_count = 0
    
    @current_user.sessions.where(completed: true).find_each do |session|
      deleted = Privacy::AudioCleanupService.new.send(:cleanup_processed_audio_if_enabled, session)
      deleted_count += deleted if deleted
    end
    
    if deleted_count > 0
      flash[:notice] += " Additionally, #{deleted_count} processed audio files were cleaned up."
    end
  end
end
