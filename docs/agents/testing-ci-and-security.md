# Layering, tests, CI and security scanning

> Moved verbatim from `CLAUDE.md` on 2026-11-11 (no upward references, test infrastructure, gem publish workflow, security scanning). `CLAUDE.md` points here; keep this file accurate whenever the behaviour it describes changes.

## No upward references

This is the lowest Thecore layer: it must never reference gems above it (`model_driven_api`, `rails_admin` via `thecore_ui_rails_admin`). Until 3.5.15 `Api::LdapServer` called `::ModelDrivenApi.smart_merge` (a no-op merge with `{}`) and `RailsAdmin::LdapServer` called `rails_admin` unconditionally, so loading `LdapServer` crashed in any app without those gems. Now `json_attrs` is plain `json_attrs || {}` and the RailsAdmin block runs only `if respond_to?(:rails_admin)`. Covered by `test/ldap_server_json_attrs_test.rb`. 3.5.16 also removed an empty scaffolded `Endpoints::LdapServer < NonCrudEndpoints` (NonCrudEndpoints is model_driven_api's): harmless with lazy autoloading, a `NameError` at boot with eager loading. `test/eager_load_test.rb` eager-loads the whole engine without model_driven_api to keep this class of bug out (the dummy app gained a Devise initializer so `User` can load).

## Test infrastructure

- **Postgres only** — like every Thecore gem and host app, tests run on PostgreSQL, never SQLite (no `sqlite3` gem in the bundle; `pg` is the dev dependency). `test/dummy/config/database.yml` uses the `postgresql` adapter (`PGHOST`/`PGPORT`/`PGUSER`/`PGPASSWORD`, defaulting to `db`/`5432`/`postgres`/`postgres`) with databases `thecore_auth_commons_development`/`_test`/`_production`.
- **`DATABASE_URL` swap in `test/dummy/config/boot.rb`** — `DATABASE_URL` overrides `database.yml`, and the devcontainer points it at the host app's dev DB (`mytrack_dev`), which a schema load or `db:test:prepare` (drop + create) would clobber. `boot.rb` keeps `DATABASE_URL`'s server/credentials but always rewrites its database name to `thecore_auth_commons_<RAILS_ENV>`. It lives in `boot.rb` rather than `test/test_helper.rb` so every entry point (`bin/rails db:*`, Rails' spawned `db:test:prepare` subprocess) is covered; the test helper no longer sets `DATABASE_URL` at all.
- **Schema from the engine's own migrations** — the dummy app has no `db/` of its own: `test/test_helper.rb` points `migrations_paths` at the gem's `db/migrate` and runs them (idempotent) before the suite, so tests can use `users`/`roles`/`role_users`/`ldap_servers`.
- **One-time setup**: `cd test/dummy && RAILS_ENV=test bin/rails db:create`. Then run the suite with `bin/test` from the gem root.

## CI/CD — gem publish (`.github/workflows/gempush.yml`)

The RubyGems publish workflow's `on: push` trigger is scoped to `branches: [release/3]` only, not an unscoped `push`. This was tightened after an incident on a sibling repo (`thecore_generators`) where an unscoped trigger published a version bump pushed to an unreviewed feature branch. Keep the trigger scoped to `release/3` so publishing only ever happens on a merge/push to the actual release branch.

## Security scanning

Configured in the GitHub repository settings, not in files:

- **CodeQL** default setup (Ruby, the Actions workflows, and JavaScript/TypeScript where the gem
  ships any): on every push to `release/3`, on pull requests and weekly. Findings: Security → Code
  scanning.
- **Secret scanning with push protection**: a push containing a recognised secret is rejected. It
  is the only check that blocks anything. If it fires on a real secret, remove it from the commit and
  rotate the secret; never bypass it.
- **Dependabot alerts and security updates**, but no `dependabot.yml`, so no routine version-bump
  pull requests. This gem commits no `Gemfile.lock`, so Dependabot only sees the gemspec and the
  workflow Actions: CVEs in the resolved Ruby dependencies are caught by `bundler-audit` in the host
  apps' pipelines, whose `Gemfile.lock` resolves every ATOM.
- Findings never block a release: GitHub notifies the owner. When one needs work, open a GitHub
  issue (see Agent skills in `CLAUDE.md`).
