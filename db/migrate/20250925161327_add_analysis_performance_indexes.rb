class AddAnalysisPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    # Add GIN index for JSONB analysis_json column for faster queries on nested data
    add_index :sessions, :analysis_json, using: :gin, name: 'index_sessions_on_analysis_json_gin'

    # Composite indexes for common query patterns
    add_index :sessions, [ :user_id, :completed, :created_at ], name: 'index_sessions_on_user_completed_date'
    add_index :sessions, [ :user_id, :processing_state ], name: 'index_sessions_on_user_processing_state'

    # Issues table performance improvements
    add_index :issues, [ :session_id, :category, :severity ], name: 'index_issues_on_session_category_severity'
    add_index :issues, [ :session_id, :start_ms ], name: 'index_issues_on_session_start_time'

    # Additional indexes for insights and analytics
    add_index :sessions, [ :created_at, :completed ], name: 'index_sessions_on_date_completed'
    add_index :sessions, :minimum_duration_enforced, name: 'index_sessions_on_duration_enforced'

    # User issue embeddings performance (if table exists)
    add_index :user_issue_embeddings, [ :user_id, :created_at ], name: 'index_embeddings_on_user_date' if table_exists?(:user_issue_embeddings)
  end
end
