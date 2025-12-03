class AddOauthFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :google_uid, :string
    add_column :users, :apple_uid, :string
    add_column :users, :auth_provider, :string

    add_index :users, :google_uid, unique: true, where: "google_uid IS NOT NULL"
    add_index :users, :apple_uid, unique: true, where: "apple_uid IS NOT NULL"
  end
end
