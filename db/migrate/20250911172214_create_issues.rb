class CreateIssues < ActiveRecord::Migration[8.0]
  def change
    create_table :issues do |t|
      t.references :session, null: false, foreign_key: true
      t.string :kind
      t.float :label_confidence
      t.integer :start_ms
      t.integer :end_ms
      t.text :text
      t.text :rationale
      t.string :source
      t.text :rewrite
      t.text :tip

      t.timestamps
    end
  end
end
