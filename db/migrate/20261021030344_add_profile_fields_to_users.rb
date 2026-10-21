class AddProfileFieldsToUsers < ActiveRecord::Migration[8.1]
  class MigrationUser < ApplicationRecord
    self.table_name = "users"
  end

  def up
    rename_column :users, :name, :display_name
    change_column_null :users, :display_name, true
    add_column :users, :username, :string
    add_column :users, :bio, :string, limit: 160

    # Give every existing user a unique username built from the email address
    MigrationUser.reset_column_information
    taken = []
    MigrationUser.order(:id).each do |user|
      base = user.email_address.split("@").first.downcase.gsub(/[^a-z0-9_]/, "_")
      base = base.ljust(3, "_").first(20)
      candidate = base
      counter = 1
      while taken.include?(candidate)
        counter += 1
        candidate = "#{base.first(20 - counter.to_s.length)}#{counter}"
      end
      taken << candidate
      user.update_columns(username: candidate)
    end

    change_column_null :users, :username, false
    add_index :users, :username, unique: true
  end

  def down
    remove_index :users, :username
    remove_column :users, :bio
    remove_column :users, :username
    execute "UPDATE users SET display_name = split_part(email_address, '@', 1) WHERE display_name IS NULL"
    change_column_null :users, :display_name, false
    rename_column :users, :display_name, :name
  end
end
