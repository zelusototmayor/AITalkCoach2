class AddIsMockToTrialSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :trial_sessions, :is_mock, :boolean, default: false, null: false
  end
end
