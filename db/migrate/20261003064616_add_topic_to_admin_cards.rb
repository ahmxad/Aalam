class AddTopicToAdminCards < ActiveRecord::Migration[8.1]
  def change
    add_reference :admin_cards, :topic, null: true, foreign_key: { to_table: :admin_topics }
  end
end
