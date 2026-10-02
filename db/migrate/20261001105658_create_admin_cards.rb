class CreateAdminCards < ActiveRecord::Migration[8.1]
  def change
    create_table :admin_cards do |t|
      t.string :title

      t.timestamps
    end
  end
end
