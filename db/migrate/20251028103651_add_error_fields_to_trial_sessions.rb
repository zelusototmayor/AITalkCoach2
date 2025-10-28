class AddErrorFieldsToTrialSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :trial_sessions, :incomplete_reason, :string
    add_column :trial_sessions, :error_text, :text
  end
end
