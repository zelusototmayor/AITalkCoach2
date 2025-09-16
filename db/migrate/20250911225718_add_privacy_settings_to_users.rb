class AddPrivacySettingsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :auto_delete_audio_days, :integer, default: 30
    add_column :users, :privacy_mode, :boolean, default: false
    add_column :users, :delete_processed_audio, :boolean, default: true
  end
end
