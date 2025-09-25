class AddSpeechContextToSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :sessions, :speech_context, :string
  end
end
