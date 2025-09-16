class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    # Sessions table - critical for app performance
    add_index :sessions, [:user_id, :completed], name: 'index_sessions_on_user_and_completed'
    add_index :sessions, [:user_id, :created_at], name: 'index_sessions_on_user_and_created_at'
    add_index :sessions, [:completed, :created_at], name: 'index_sessions_on_completed_and_created_at'
    add_index :sessions, :processing_state, name: 'index_sessions_on_processing_state'
    
    # Issues table - for filtering and grouping
    add_index :issues, [:session_id, :category], name: 'index_issues_on_session_and_category'
    add_index :issues, [:session_id, :start_ms], name: 'index_issues_on_session_and_start_ms'
    add_index :issues, :category, name: 'index_issues_on_category'
    add_index :issues, :severity, name: 'index_issues_on_severity'
    
    # User issue embeddings - for AI recommendations
    add_index :user_issue_embeddings, [:user_id, :created_at], name: 'index_user_embeddings_on_user_and_created_at'
    
    # AI caches - for fast lookups
    add_index :ai_caches, :created_at, name: 'index_ai_caches_on_created_at'
    add_index :ai_caches, :updated_at, name: 'index_ai_caches_on_updated_at'
  end
end
