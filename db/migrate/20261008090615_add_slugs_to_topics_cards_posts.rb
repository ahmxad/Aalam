class AddSlugsToTopicsCardsPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :admin_topics, :slug, :string
    add_column :admin_cards, :slug, :string
    add_column :posts, :slug, :string
  end
end
