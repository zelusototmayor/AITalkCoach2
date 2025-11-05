class AddProcessingStartedAtToSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :sessions, :processing_started_at, :datetime
    add_column :trial_sessions, :processing_started_at, :datetime
  end
end
