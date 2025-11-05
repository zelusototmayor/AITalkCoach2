class CreateBlogPosts < ActiveRecord::Migration[8.0]
  def change
    create_table :blog_posts do |t|
      t.string :title, null: false
      t.string :slug, null: false
      t.text :excerpt
      t.string :meta_description
      t.string :meta_keywords
      t.boolean :published, default: false, null: false
      t.datetime :published_at
      t.string :author
      t.integer :reading_time
      t.integer :view_count, default: 0, null: false

      t.timestamps
    end
    add_index :blog_posts, :slug, unique: true
    add_index :blog_posts, :published
    add_index :blog_posts, :published_at
  end
end
