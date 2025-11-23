class AddTargetWpmToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :target_wpm, :integer
  end
end
