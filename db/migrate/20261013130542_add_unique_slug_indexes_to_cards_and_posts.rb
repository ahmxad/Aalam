class AddUniqueSlugIndexesToCardsAndPosts < ActiveRecord::Migration[8.1]
  def change
    add_index :admin_cards, [ :topic_id, :slug ], unique: true
    add_index :posts, [ :card_id, :slug ], unique: true
  end
end
