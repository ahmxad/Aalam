class CreateSlugHistories < ActiveRecord::Migration[8.1]
  def change
    create_table :slug_histories do |t|
      t.references :sluggable, polymorphic: true, null: false
      t.string :slug, null: false
      t.bigint :scope_id

      t.timestamps
    end

    add_index :slug_histories, [ :sluggable_type, :slug, :scope_id ], name: "index_slug_histories_on_lookup"
  end
end
