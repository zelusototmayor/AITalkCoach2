class CreateAiCaches < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_caches, id: false do |t|
      t.string :key, primary_key: true
      t.text :value

      t.timestamps
    end
  end
end
