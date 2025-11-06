class AddRelevanceToSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :sessions, :relevance_score, :float
    add_column :sessions, :relevance_feedback, :text
    add_column :sessions, :off_topic, :boolean, default: false
    add_column :sessions, :retake_count, :integer, default: 0
    add_column :sessions, :is_retake, :boolean, default: false
  end
end
