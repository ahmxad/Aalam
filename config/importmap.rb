# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "slug_check", to: "slug_check.js"
pin "card_slug_check", to: "card_slug_check.js"
pin "post_slug_check", to: "post_slug_check.js"
