class AddPromoCodeToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :promo_code, :string
  end
end
