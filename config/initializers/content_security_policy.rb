# Be sure to restart your server when you modify this file.
require_relative "../../lib/storage_hosts"
# Content security policy: tells the browser which sources of scripts, styles, fonts
# and images are allowed, so an injected script cannot run or send data elsewhere.
Rails.application.configure do
  # Where uploaded files live when they are not on the local disk. The browser uploads straight
  # to this address (connect-src) and shows the pictures that it serves (img-src).
  storage_hosts = StorageHosts.for(Rails.application.credentials)
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.base_uri    :self
    policy.form_action :self, "https://github.com", "https://accounts.google.com"
    policy.frame_ancestors :self
    policy.object_src  :none
    policy.script_src  :self
    policy.connect_src :self, *storage_hosts
    # Google Fonts: the stylesheet comes from googleapis, the font files from gstatic
    policy.style_src   :self, "https://fonts.googleapis.com"
    policy.font_src    :self, "https://fonts.gstatic.com", :data
    # data: is needed because the UI framework embeds small SVG icons in its CSS
    policy.img_src     :self, :data, :blob, *storage_hosts
  end

  # A fresh random nonce for every request, so it also works for visitors without a session
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src style-src]

  # Report violations without enforcing the policy. Remove this line to enforce it.
  # config.content_security_policy_report_only = true
end
