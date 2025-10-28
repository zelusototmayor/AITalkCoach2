class AddStripePaymentMethodIdToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :stripe_payment_method_id, :string
  end
end
