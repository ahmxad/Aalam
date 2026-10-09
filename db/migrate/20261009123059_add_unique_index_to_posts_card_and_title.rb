
class AddUniqueIndexToPostsCardAndTitle < ActiveRecord::Migration[8.1]
  def change
    add_index :posts, "card_id, LOWER(title)",
              unique: true,
              name: "index_posts_on_card_id_and_lower_title"
  end
end
