class AddPasswordSetToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :password_set, :boolean, null: false, default: true

    # People who signed up through another service were given a password that nobody knows.
    # Their connected account was created at the same moment as the user.
    execute <<~SQL
      UPDATE users SET password_set = FALSE
      WHERE EXISTS (
        SELECT 1 FROM identities
        WHERE identities.user_id = users.id
          AND identities.created_at BETWEEN users.created_at - INTERVAL '10 seconds'
                                        AND users.created_at + INTERVAL '10 seconds'
      )
    SQL
  end

  def down
    remove_column :users, :password_set
  end
end
