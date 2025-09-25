class AddMinimumDurationEnforcedToSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :sessions, :minimum_duration_enforced, :boolean, default: true, null: false
    add_index :sessions, :minimum_duration_enforced
  end
end
