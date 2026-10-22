class CreateIdentities < ActiveRecord::Migration[8.1]
  def change
    create_table :identities do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.string :provider, null: false
      t.string :uid, null: false
      t.timestamps
    end

    # One account of a service belongs to one user, and a user has at most one account per service
    add_index :identities, [ :provider, :uid ], unique: true
    add_index :identities, [ :user_id, :provider ], unique: true
  end
end