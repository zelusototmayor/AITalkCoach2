class CreateTrialSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :trial_sessions do |t|
      t.string :token, null: false, index: { unique: true }
      t.string :title, null: false
      t.string :language, default: 'en'
      t.string :media_kind, default: 'audio'
      t.integer :target_seconds, default: 30
      t.integer :duration_ms
      t.text :analysis_data
      t.string :processing_state, default: 'pending'
      t.boolean :completed, default: false
      t.datetime :processed_at
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :trial_sessions, :expires_at
    add_index :trial_sessions, :processing_state
    add_index :trial_sessions, :created_at
  end
end
