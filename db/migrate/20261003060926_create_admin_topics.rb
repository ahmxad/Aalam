class CreateAdminTopics < ActiveRecord::Migration[8.1]
  def change
    create_table :admin_topics do |t|
      t.string :title

      t.timestamps
    end
  end
end
