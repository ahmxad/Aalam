class AddCardToPosts < ActiveRecord::Migration[8.1]
  def change
    add_reference :posts, :card,
                  null: false,
                  foreign_key: { to_table: :admin_cards }
  end
end
