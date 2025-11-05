class AddPreferredLanguageToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :preferred_language, :string, default: "en", null: false
    add_index :users, :preferred_language
  end
end
