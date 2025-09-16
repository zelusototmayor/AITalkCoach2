class CreateUserIssueEmbeddings < ActiveRecord::Migration[8.0]
  def change
    create_table :user_issue_embeddings do |t|
      t.references :user, null: false, foreign_key: true
      t.text :embedding_json
      t.text :payload

      t.timestamps
    end
  end
end
