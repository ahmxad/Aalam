require "test_helper"
require_relative "../../db/migrate/20261021030344_add_profile_fields_to_users"

class AddProfileFieldsToUsersTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  self.use_transactional_tests = false

  setup do
    @connection = ActiveRecord::Base.lease_connection
    @original_search_path = @connection.schema_search_path
    @schema = "profile_migration_#{Process.pid}"
    @connection.create_schema(@schema)
    @connection.schema_search_path = @schema
    @connection.create_table(:users) do |t|
      t.string :email_address, null: false
      t.string :name, null: false
    end
    @connection.execute <<~SQL
      INSERT INTO users (id, email_address, name) VALUES
        (1, 'private.person@example.com', 'private.person'),
        (2, 'admin@example.com', 'admin'),
        (9223372036854775806, 'secret@example.com', 'secret'),
        (9223372036854775807, 'another.secret@example.com', 'another.secret')
    SQL
  end

  teardown do
    @connection.schema_search_path = @original_search_path
    @connection.drop_schema(@schema, if_exists: true, force: :cascade)
    @connection.schema_cache.clear!
    AddProfileFieldsToUsers::MigrationUser.reset_column_information
  end

  test "backfills unique public identifiers without exposing email names" do
    AddProfileFieldsToUsers.new.migrate(:up)

    rows = @connection.select_all("SELECT * FROM users ORDER BY id").to_a
    usernames = rows.pluck("username")
    assert_equal usernames.uniq, usernames
    assert_equal "user_1", usernames.first
    assert_empty usernames & %w[admin administrator root support aalam system me]
    rows.each do |row|
      assert_match(/\A[a-z0-9_]{3,20}\z/, row["username"])
      assert_equal row["username"], row["display_name"]
      assert_not_includes row["display_name"], row["email_address"].split("@").first
    end
    assert_equal "user_922337203685477", usernames[2]
    assert_equal "user_922337203685472", usernames[3]
    assert @connection.index_exists?(:users, :username, unique: true)
    assert_not @connection.columns(:users).find { |column| column.name == "username" }.null

    AddProfileFieldsToUsers.new.migrate(:down)

    assert_equal usernames, @connection.select_values("SELECT name FROM users ORDER BY id")
    assert_not @connection.column_exists?(:users, :username)
    assert_not @connection.columns(:users).find { |column| column.name == "name" }.null
  end
end
