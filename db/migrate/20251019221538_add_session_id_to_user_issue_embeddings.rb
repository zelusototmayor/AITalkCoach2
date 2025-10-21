class AddSessionIdToUserIssueEmbeddings < ActiveRecord::Migration[8.0]
  def change
    add_reference :user_issue_embeddings, :session, foreign_key: true, index: true
    add_column :user_issue_embeddings, :embedding_type, :string
    add_column :user_issue_embeddings, :reference_id, :integer
    add_column :user_issue_embeddings, :vector_data, :text
    add_column :user_issue_embeddings, :ai_model_name, :string
    add_column :user_issue_embeddings, :dimensions, :integer
    add_column :user_issue_embeddings, :metadata_json, :text

    add_index :user_issue_embeddings, [:session_id, :embedding_type, :reference_id],
              name: 'index_embeddings_on_session_type_ref'
  end
end
