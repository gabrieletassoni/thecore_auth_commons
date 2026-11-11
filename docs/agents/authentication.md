# Authentication

> Moved verbatim from `CLAUDE.md` on 2026-11-11 (login flow, LDAP group mapping, OAuth2, seeds, LdapServer removal, Devise 5). `CLAUDE.md` points here; keep this file accurate whenever the behaviour it describes changes.

## Login flow

`Users::SessionsController#create`:
1. Try Devise local auth (`warden.authenticate`).
2. On failure, try `Ldap::Authenticator#authenticate` — iterates `LdapServer.all` (ordered by `priority`), admin-binds, searches for the user by `auth_field`, then binds as the user DN to verify credentials.
3. On LDAP success, calls `ThecoreAuthCommons.align_user` which find-or-initializes the User, maps LDAP attributes to model fields, assigns roles from `memberOf` groups, and saves with `validate: false`.
4. If both fail, renders the login form with `401`.

## LDAP group → role mapping

`align_user` reads `entry[:memberOf]`, extracts the CN (`group.split(",").first.split("=").last`), and calls `Role.find_or_create_by(name: group_name)`. Groups named `Administrators`, `Domain Admins`, `Schema Admins`, `Enterprise Admins`, `admins`, `administrators` also set `user.admin = true` (only promotes, never demotes an existing admin).

## OAuth2

Providers registered only when the relevant env vars are all present (`entra_id_vars?` / `google_oauth2_vars?`). `check_user(email, name, surname, provider)` gets the email the provider verified, never one from request params (callers pass `request.env['omniauth.auth']`'s). It finds the user by email (stripped and downcased) and creates them if missing, with `auth_source = provider`, a random secure password, no admin and no roles. An existing user only gets `name`/`surname` updated: password, `admin` and `auth_source` are untouched, so a local password keeps working. `name`/`surname` are set only when the host's `User` has them. It returns `nil` for a blank email or a user that can't be saved (e.g. a host validation OAuth can't satisfy), and callers treat `nil` as "not registered". Until 3.6.2 it set `admin = true` on every OAuth login and rewrote the password each time (Odoo #5837). Covered by `test/check_user_test.rb`. Uses `omniauth-entra-id` and `omniauth-google-oauth2`.

## Seeds

Run `rails db:seed` (or `rails thecore_auth_commons:db:seed` in host context). Creates:
- Admin user `admin@BASE_DOMAIN` (env var, default `example.com`), via `ThecoreAuthCommons.seed_first_admin`, only when no admin exists (keep this guard: existing installations must not change). Password: `ADMIN_PASSWORD` if set, else `generate_secure_password` written to `storage/admin_initial_password` (`File::EXCL`, `0600`), logged as its path only, never the value. An existing file is never overwritten: the admin is then not created and the log says so (the entrypoint reseeds on every start, so that line repeats until someone deletes the file). If the save fails the file is deleted and the error re-raised, so no stale file blocks the next seed. Until 3.6.1 the fallback was a fixed `Change#1` on every installation without `ADMIN_PASSWORD`. Covered by `test/seed_first_admin_test.rb`.
- `Predicate`: `can`, `cannot`
- `Action`: `manage`, `create`, `read`, `update`, `destroy`
- `Target`: `all` + each `ApplicationRecord.subclass` underscored — so **seeds must run after all models are loaded** (Zeitwerk eager-loads first).

## LdapServer destroy keeps its users

- **LdapServer destroy keeps its users**: `after_destroy :turn_users_into_local_users` sets `auth_source = "local"` (via `update_all`) on every `User` whose `auth_source == "ldap #{id}"`; record, roles and everything else stay as they were, and logging in again needs a local password set by hand. Until 3.6.0 it destroyed those users instead, and that stripped their roles even when the destroy was refused: a `User`'s `dependent: :destroy` children (`role_users`) go before a later `before_destroy` guard (the host's "user has logged time" guard) aborts, and the abort's rollback is swallowed inside the `LdapServer`'s own transaction (a nested `transaction` without `requires_new`), so the user survived without roles. Covered by `test/ldap_server_removal_test.rb`.

## Devise 5 (3.6.0)

Requires `devise >= 5.0.4, < 6` (was `~> 4.8`) for CVE-2026-40295: with `:timeoutable` (which `User` uses), Devise <= 5.0.3 redirected a non-GET request hitting an expired session to the unvalidated, attacker-controlled `Referer` (open redirect). The confirmable race (CVE-2026-32700) does not apply (`User` has no `:confirmable`). No removed Devise 5 API is used anywhere in the ecosystem; host-app checks (session + JWT login, 29 auth routes with and without Google/Entra providers) are identical on 4.9.4 and 5.0.4. The host's `test/integration/devise_timeout_open_redirect_test.rb` reproduces the CVE (red on 4.9.4).
