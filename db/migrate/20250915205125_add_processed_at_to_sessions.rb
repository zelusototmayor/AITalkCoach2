class AddProcessedAtToSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :sessions, :processed_at, :datetime
  end
end
