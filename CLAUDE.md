# CLAUDE.md — thecore_auth_commons

## Purpose

Rails engine that provides authentication (Devise: local, LDAP, OAuth2) and database-driven role-based authorization (CanCanCan) for the Thecore ecosystem. Lowest Thecore layer; public gem on RubyGems.

## Where things are

- `app/models/` — `User`, `Role`, `RoleUser`, `Permission` (predicate + action + target), `PermissionRole`, vocabularies `Predicate`/`Action`/`Target`, `LdapServer` (+ its `api`/`rails_admin` concerns)
- `app/controllers/users/` — `SessionsController` (local → LDAP fallback), `OmniauthCallbacksController`
- `app/services/ldap/authenticator.rb`, `app/jobs/background_ldap_import_job.rb`
- `config/initializers/` — `abilities.rb` (base rules), `concern_cancancan.rb` + `after_initialize.rb` (DB permissions into the host's `Ability`), `omniauth.rb`
- `lib/thecore_auth_commons.rb` — `seed_first_admin`, `check_user`, `align_user`, `generate_secure_password`, `import_ldap_users_task`
- `db/seeds.rb`, `db/migrate/`; full annotated tree in `docs/agents/repository-layout.md`

## Read before working on…

| Topic | File |
| --- | --- |
| Full file tree | `docs/agents/repository-layout.md` |
| Ability layers, permission order, multiple roles, `can`/`cannot` | `docs/agents/authorization.md` |
| Login flow, LDAP group → role, OAuth2 `check_user`, seeds/first admin, LdapServer removal, Devise 5 | `docs/agents/authentication.md` |
| No upward references, Postgres test setup, gem publish workflow, security scanning | `docs/agents/testing-ci-and-security.md` |
| Tickets (GitHub Issues), triage labels, glossary/ADR layout | `docs/agents/issue-tracker.md`, `triage-labels.md`, `domain.md` |

## Key conventions

- **can + can is always additive**: only an explicit `cannot` revokes a grant; DB permissions apply in `permission.id` order, never role-assignment order (`docs/agents/authorization.md`). The host app's `Ability` class must exist; this engine does not define it.
- **Adding a new permission at runtime**: create `Permission` (predicate + action + target), create `PermissionRole` linking it to a `Role`, assign the `Role` to the `User`. Takes effect on next request (Ability is instantiated per-request).
- **Never delete Action records**: `Abilities::ThecoreAuthCommons` explicitly prevents `create Action` to guard vocabulary integrity.
- **`align_user` saves with `validate: false`**: intentional — LDAP-sourced users may lack fields required by the host app's validations (e.g. `name`, `surname`). Do not change this without checking host-app model constraints.
- **`generate_secure_password`**: always produces a password compliant with the policy (upper + lower + digit + special). Used for LDAP/OAuth users and the seeded admin; minimum length 4, default 20; draws from `SecureRandom` (since 3.6.2; before, Ruby's default PRNG).
- **OAuth `check_user`** takes the email only from the provider-verified `omniauth.auth`, never from request params; never grants admin, never rewrites an existing user's password.
- **First admin** is seeded only when no admin exists (keep this guard: existing installations must not change); its generated password is never logged. Seeds must run after all models are loaded (`Target` rows come from `ApplicationRecord.subclasses`).
- **LdapServer destroy keeps its users** (turns them into local users); never destroy them (`docs/agents/authentication.md`).
- **`BackgroundLdapImportJob` queue**: `"#{ENV["COMPOSE_PROJECT_NAME"]}_default"` — same pattern as the host app's scheduled jobs.
- **No upward references**: this is the lowest Thecore layer: it must never reference gems above it (`model_driven_api`, `rails_admin` via `thecore_ui_rails_admin`); `test/eager_load_test.rb` guards it.
- **Postgres only**, never SQLite. `test/dummy/config/boot.rb` rewrites `DATABASE_URL`'s database name so tests never touch the host's dev DB.
- **Gem publish**: `.github/workflows/gempush.yml` publishes when `lib/*/version.rb` changes; keep its `on: push` trigger scoped to `release/3`.
- **Secret push protection**: if it fires on a real secret, remove it from the commit and rotate the secret; never bypass it.

## Commands

- One-time setup: `cd test/dummy && RAILS_ENV=test bin/rails db:create`. Run the suite with `bin/test` from the gem root.
- Seeds: `rails db:seed` (or `rails thecore_auth_commons:db:seed` in host context).

## Development workflow

- **Update this CLAUDE.md, or the `docs/agents/` file it points to,** when adding models, changing the auth flow, adding OAuth providers, or modifying permission resolution logic.
- **Update README.md** when environment variables, setup steps, or user-facing behaviour change.
- The engine has no host-specific logic. Keep it generic; host-app customization belongs in `config/initializers/` of the host app.

## Agent skills

### Issue tracker

Tasks, issues, bugs, tickets and specs for this repository live **only** in its GitHub Issues
(`gabrieletassoni/thecore_auth_commons`), handled with the `gh` CLI. See `docs/agents/issue-tracker.md`.

**Mandatory rule.** Whenever a skill or development work creates, reads, updates, comments on,
assigns, blocks or closes a task, issue, bug, ticket or spec (for example /to-tickets, /to-spec,
/triage, /wayfinder, /implement, /diagnosing-bugs, /code-review, closing a piece of work, a bug found
during a session), do it in this repository's GitHub Issues following `docs/agents/issue-tracker.md`.
Never use Odoo, `.scratch/` or local Markdown files as a tracker: Odoo is only for the repositories
on Bancolini's GitLab. `#123` means a GitHub issue number of this repository. If `gh` doesn't work,
stop and say so instead of falling back to another tracker.

### Triage labels

The five canonical triage roles map to GitHub labels with the same name (`needs-triage`,
`needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `GLOSSARY.md` and `docs/adr/` at the repo root, created lazily when the first
term or decision is resolved. See `docs/agents/domain.md`.

### Skills

Matt Pocock's skills come from the `mattpocock-skills` Claude Code plugin installed on the
developer's **host** (`claude plugins install mattpocock-skills`, official marketplace), never
vendored here: no `.agents/skills/`, `.claude/commands/` or `skills-lock.json`. Its `ask-matt` skill
maps how the skills connect.
