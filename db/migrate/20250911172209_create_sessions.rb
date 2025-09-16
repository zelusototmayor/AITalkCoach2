class CreateSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title
      t.string :language
      t.string :media_kind
      t.integer :duration_ms
      t.integer :target_seconds
      t.boolean :completed
      t.string :incomplete_reason
      t.string :processing_state
      t.text :error_text
      t.text :analysis_json

      t.timestamps
    end
  end
end
