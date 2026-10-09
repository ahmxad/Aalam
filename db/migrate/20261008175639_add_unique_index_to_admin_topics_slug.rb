class AddUniqueIndexToAdminTopicsSlug < ActiveRecord::Migration[8.1]
  def change
    add_index :admin_topics, :slug, unique: true
  end
end
