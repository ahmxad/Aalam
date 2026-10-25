class AddNameAndAdminDefaultToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :name, :string
    execute "UPDATE users SET name = split_part(email_address, '@', 1)"
    change_column_null :users, :name, false

    execute "UPDATE users SET admin = false WHERE admin IS NULL"
    change_column_default :users, :admin, false
    change_column_null :users, :admin, false
  end

  def down
    change_column_null :users, :admin, true
    change_column_default :users, :admin, nil
    remove_column :users, :name
  end
end
