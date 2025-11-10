class CreatePartnerApplications < ActiveRecord::Migration[8.0]
  def change
    create_table :partner_applications do |t|
      t.string :name
      t.string :email
      t.string :partner_type
      t.text :message
      t.string :status, default: "pending"

      t.timestamps
    end

    add_index :partner_applications, :email
    add_index :partner_applications, :status
  end
end
