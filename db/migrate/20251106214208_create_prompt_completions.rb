class CreatePromptCompletions < ActiveRecord::Migration[8.0]
  def change
    create_table :prompt_completions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :prompt_identifier, null: false
      t.datetime :completed_at, null: false
      t.references :session, null: true, foreign_key: true

      t.timestamps
    end

    add_index :prompt_completions, [:user_id, :prompt_identifier], unique: true
  end
end
