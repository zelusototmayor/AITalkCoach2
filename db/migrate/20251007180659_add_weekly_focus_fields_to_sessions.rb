class AddWeeklyFocusFieldsToSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :sessions, :weekly_focus_id, :integer, null: true
    add_column :sessions, :is_planned_session, :boolean, default: false, null: false
    add_column :sessions, :planned_for_date, :date, null: true

    add_foreign_key :sessions, :weekly_focuses, column: :weekly_focus_id
    add_index :sessions, :weekly_focus_id
    add_index :sessions, [ :weekly_focus_id, :completed ]
    add_index :sessions, [ :planned_for_date, :completed ]
    add_index :sessions, [ :user_id, :planned_for_date ]
  end
end
