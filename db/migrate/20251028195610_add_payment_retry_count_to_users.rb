class AddPaymentRetryCountToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :payment_retry_count, :integer, default: 0, null: false
  end
end
