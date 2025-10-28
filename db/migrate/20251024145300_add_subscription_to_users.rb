class AddSubscriptionToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :stripe_customer_id, :string
    add_column :users, :stripe_subscription_id, :string
    add_column :users, :subscription_status, :string, default: 'free_trial'
    add_column :users, :subscription_plan, :string
    add_column :users, :trial_expires_at, :datetime
    add_column :users, :last_qualifying_session_at, :datetime
    add_column :users, :subscription_started_at, :datetime
    add_column :users, :current_period_end, :datetime

    # Add indices for efficient queries
    add_index :users, :stripe_customer_id
    add_index :users, :stripe_subscription_id
    add_index :users, :subscription_status
    add_index :users, :trial_expires_at
  end
end
