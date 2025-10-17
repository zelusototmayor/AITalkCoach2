class AddMicroTipsToSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :sessions, :micro_tips, :json, default: []
    add_column :sessions, :coaching_insights, :json, default: {}
  end
end
