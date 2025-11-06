class AddPromptTextToSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :sessions, :prompt_text, :text
  end
end
