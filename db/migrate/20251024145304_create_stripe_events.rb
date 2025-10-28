class CreateStripeEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :stripe_events do |t|
      t.string :stripe_event_id
      t.string :event_type
      t.datetime :processed_at
      t.text :payload

      t.timestamps
    end
    add_index :stripe_events, :stripe_event_id, unique: true
  end
end
