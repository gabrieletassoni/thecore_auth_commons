# Changelog

## [3.8.1] - 2026-11-26

### Security
- `User#check_password_and_confirmation_equal` (a `validate` callback) is `private` (host Odoo #6314): a callback is lifecycle, not API, and the API's `a[methods]` could call it. It still validates as before.

## [3.8.0] - 2026-11-25

### Security
- **Failed-login limit per IP** (host Odoo #6052). `ThecoreAuthCommons::LoginFailureThrottle`, a middleware right after `ActionDispatch::RemoteIp`: after `THECORE_LOGIN_FAILURES_PER_MINUTE` (default 20, `0` = off) failed attempts in the current minute from one IP, `POST /users/sign_in`, `POST /api/vN/authenticate` and the OAuth callbacks answer 429 (`Retry-After`, JSON on `/api/`) until the minute ends. Only failures count (401, or an OAuth callback refused), so the right password is never limited, behind a NAT either. X-Forwarded-For counts only from a trusted proxy. Counters in Redis (`THECORE_LOGIN_THROTTLE_REDIS_URL`, else `REDIS_URL`; fails open if Redis is down), in memory without it, nowhere in the test environment unless a test sets `LoginFailureThrottle.store`.
- **`ldap_servers.admin_password` is write-only** (host Odoo #6084, host ADR 0046 point 10): never serialized (`serializable_hash` drops it whatever `only`/`methods` ask, and ignores `methods:`), not in `ransackable_attributes`, a RailsAdmin `:password` field (edit only, blank keeps it), declared in `LdapServer.write_only_attributes` (model_driven_api >= 3.17.0 keeps it out of v3), and its index is dropped (migration `RemoveAdminPasswordIndexFromLdapServers`).

### Changed
- Requires `thecore_settings` >= 3.1.0 (write-only Secret settings).

## [3.6.5] - 2026-11-24

### Fixed
- `LdapServer#test_connection` raised `Errno::ECONNREFUSED` for a host that refuses the connection: net-ldap raises the bare `SystemCallError` for a single host, not a `Net::LDAP::Error`. It is now a failure with the reason, like the other connection errors (thecore_ui_rails_admin#17).
- The "no admin credentials" reason is translated (`ldap_server.test_connection.no_admin_credentials`, en + it).

## [3.6.4] - 2026-11-24

### Fixed
- **`LdapServer#test_connection` reports the outcome** (thecore_ui_rails_admin#17). It returns an `LdapServer::ConnectionResult` (`success?`, `message`) instead of nothing: a refused admin bind is a failure with the server's reason (it used to look like success), and missing admin credentials or an unreachable/unresolvable host are failures with a message instead of a raised `Net::LDAP` error.

## [3.6.3] - 2026-10-28

### Security
- **OAuth login no longer grants admin** (Odoo #5837) — `check_user` used to set `admin = true` for every Google/Entra login and regenerate the password on each one. New OAuth users are now created without admin or roles; an existing user keeps password, admin flag and `auth_source` (only `name`/`surname` are refreshed). It returns `nil` for a blank email or an unsavable user instead of an unsaved record, and no longer crashes on a `User` without `name`/`surname` columns.

## [3.6.2] - 2026-10-28

### Security
- **No fixed admin password at seed time** — without `ADMIN_PASSWORD` the seed used to create the first admin with `Change#1`. It now generates a random password (`SecureRandom`) and writes it to `storage/admin_initial_password` (`0600`, never overwritten, never logged). Only new installations are affected: the admin is still created only when none exists.
- `generate_secure_password` draws from `SecureRandom`.

## [3.5.14] - 2026-09-08

### Fixed
- **`lib/thecore_auth_commons.rb` require order** — `activerecord-nulldb-adapter` reaches into `ActiveRecord::ConnectionAdapters::SqlTypeMetadata::Deduplicable`, which isn't guaranteed loaded yet under a bare, non-Rails-booted require chain (e.g. `model_driven_api`'s plain minitest path), raising `NameError: uninitialized constant ...Deduplicable`. Now requires `active_record` first.
- Own dummy test app boot: added missing `actionmailer`/`activestorage` dev dependencies (the dummy `test.rb` config references both, but `rails/all` silently swallows their railtie `require` in a `rescue LoadError` when absent), relaxed the `sqlite3` dev dependency pin (conflicted with activerecord 8.x's own `>= 2.1` requirement), forced SQLite for this gem's own tests (matching `thecore_ui_commons`'s pattern, so the ambient devcontainer `DATABASE_URL` doesn't leak in), and added the dummy app's own `Ability` stub (matching `thecore_ui_rails_admin`'s precedent). None of this affects the published gem's runtime behavior.
