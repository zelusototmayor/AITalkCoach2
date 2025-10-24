class AddAnalysisDataToSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :sessions, :analysis_data, :json, default: {}
  end
end
