require "test_helper"

class StorageHostsTest < ActiveSupport::TestCase
  test "local storage needs no extra address" do
    assert_empty StorageHosts.for({})
    assert_empty StorageHosts.for(r2: { account_id: "abc123" })
    assert_empty StorageHosts.for(r2: { bucket: "files" })
  end

  test "R2 storage allows exactly the address of the account" do
    assert_equal [ "https://abc123.r2.cloudflarestorage.com" ],
                 StorageHosts.for(r2: { account_id: "abc123", bucket: "files" })
  end
end
