# The web addresses that the browser has to reach when uploaded files are kept in Cloudflare R2.
# With local storage there are none, so the content security policy stays as strict as before.
module StorageHosts
  def self.for(credentials)
    account_id = credentials.dig(:r2, :account_id).presence
    bucket = credentials.dig(:r2, :bucket).presence
    return [] unless account_id && bucket

    [ "https://#{account_id}.r2.cloudflarestorage.com" ]
  end
end
