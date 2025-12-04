class AddToursCompletedToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :tours_completed, :json, default: {}
  end
end
