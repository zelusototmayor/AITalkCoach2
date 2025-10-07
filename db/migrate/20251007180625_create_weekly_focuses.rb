class CreateWeeklyFocuses < ActiveRecord::Migration[8.0]
  def change
    create_table :weekly_focuses do |t|
      t.references :user, null: false, foreign_key: true
      t.string :focus_type, null: false
      t.decimal :target_value, precision: 10, scale: 4, null: false
      t.decimal :starting_value, precision: 10, scale: 4, null: false
      t.date :week_start, null: false
      t.date :week_end, null: false
      t.integer :target_sessions_per_week, default: 10, null: false
      t.string :status, default: 'active', null: false

      t.timestamps
    end

    add_index :weekly_focuses, [:user_id, :week_start]
    add_index :weekly_focuses, [:user_id, :status]
    add_index :weekly_focuses, :status
  end
end
