class AddAppleSubscriptionToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :apple_subscription_id, :string
    add_column :users, :revenuecat_customer_id, :string
    add_column :users, :subscription_platform, :string

    # Add indexes for better query performance
    add_index :users, :apple_subscription_id
    add_index :users, :revenuecat_customer_id
    add_index :users, :subscription_platform
  end
end
