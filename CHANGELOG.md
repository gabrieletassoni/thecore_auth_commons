# Changelog

## [3.5.14] - 2026-09-08

### Fixed
- **`lib/thecore_auth_commons.rb` require order** — `activerecord-nulldb-adapter` reaches into `ActiveRecord::ConnectionAdapters::SqlTypeMetadata::Deduplicable`, which isn't guaranteed loaded yet under a bare, non-Rails-booted require chain (e.g. `model_driven_api`'s plain minitest path), raising `NameError: uninitialized constant ...Deduplicable`. Now requires `active_record` first.
- Own dummy test app boot: added missing `actionmailer`/`activestorage` dev dependencies (the dummy `test.rb` config references both, but `rails/all` silently swallows their railtie `require` in a `rescue LoadError` when absent), relaxed the `sqlite3` dev dependency pin (conflicted with activerecord 8.x's own `>= 2.1` requirement), forced SQLite for this gem's own tests (matching `thecore_ui_commons`'s pattern, so the ambient devcontainer `DATABASE_URL` doesn't leak in), and added the dummy app's own `Ability` stub (matching `thecore_ui_rails_admin`'s precedent). None of this affects the published gem's runtime behavior.
