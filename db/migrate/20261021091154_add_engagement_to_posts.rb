class AddEngagementToPosts < ActiveRecord::Migration[8.1]
  def change
    create_table :comments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :post, null: false, foreign_key: true, index: false
      t.references :parent, foreign_key: { to_table: :comments }
      t.text :body, null: false
      t.integer :likes_count, null: false, default: 0
      t.integer :replies_count, null: false, default: 0
      t.timestamps
    end
    add_index :comments, [ :post_id, :created_at ]

    # One table for the likes of posts and of comments
    create_table :likes do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.references :likeable, polymorphic: true, null: false, index: false
      t.timestamps
    end
    add_index :likes, [ :user_id, :likeable_type, :likeable_id ], unique: true
    add_index :likes, [ :likeable_type, :likeable_id ]

    create_table :bookmarks do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.references :post, null: false, foreign_key: true
      t.timestamps
    end
    add_index :bookmarks, [ :user_id, :post_id ], unique: true

    add_column :posts, :likes_count, :integer, null: false, default: 0
    add_column :posts, :bookmarks_count, :integer, null: false, default: 0
    add_column :posts, :comments_count, :integer, null: false, default: 0
    add_column :posts, :shares_count, :integer, null: false, default: 0
  end
end
