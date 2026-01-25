# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin "libsodium-wrappers-sumo", to: "https://cdn.jsdelivr.net/npm/libsodium-wrappers-sumo@0.7.13/+esm", preload: true, integrity: "sha384-CJdPnuz+m6Tx0pohb/0OFVgb6A8nv501oiHzUlptTI32N9G7NrD6jx4XFqPbEc9m"
pin_all_from "app/javascript/controllers", under: "controllers"
