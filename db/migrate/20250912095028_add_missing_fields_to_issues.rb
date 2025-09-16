class AddMissingFieldsToIssues < ActiveRecord::Migration[8.0]
  def change
    add_column :issues, :category, :string
    add_column :issues, :severity, :string
    add_column :issues, :coaching_note, :text
  end
end
