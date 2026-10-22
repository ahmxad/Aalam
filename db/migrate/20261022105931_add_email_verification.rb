class AddEmailVerification < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :email_verified_at, :datetime

    # The accounts that exist today were made by the owner, so they count as verified
    execute "UPDATE users SET email_verified_at = CURRENT_TIMESTAMP"

    create_table :email_verification_codes do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.string :email, null: false
      t.string :code_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.integer :attempts, null: false, default: 0
      t.timestamps
    end
    add_index :email_verification_codes, [ :user_id, :created_at ]
  end

  def down
    drop_table :email_verification_codes
    remove_column :users, :email_verified_at
  end
end
