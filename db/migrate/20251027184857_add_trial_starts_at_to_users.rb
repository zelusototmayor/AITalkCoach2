class AddTrialStartsAtToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :trial_starts_at, :datetime
  end
end
