# Authentication

> Moved verbatim from `CLAUDE.md` on 2026-11-11 (login flow, LDAP group mapping, OAuth2, seeds, LdapServer removal, Devise 5). `CLAUDE.md` points here; keep this file accurate whenever the behaviour it describes changes.

## Login flow

`Users::SessionsController#create`:
1. Try Devise local auth (`warden.authenticate`).
2. On failure, try `Ldap::Authenticator#authenticate` — iterates `LdapServer.all` (ordered by `priority`), admin-binds, searches for the user by `auth_field`, then binds as the user DN to verify credentials.
3. On LDAP success, calls `ThecoreAuthCommons.align_user` which find-or-initializes the User, maps LDAP attributes to model fields, assigns roles from `memberOf` groups, and saves with `validate: false`.
4. If both fail, renders the login form with `401`.

## Locked users

`users.locked` (set from RailsAdmin) is enforced by `User#active_for_authentication?` (`super && !locked?`), since 3.7.0. Devise asks it on every web login (local, LDAP, OAuth: `sign_in` runs Warden's `after_set_user` hook) and on every request of an open session, so a user locked mid-session is signed out at the next request. On the sign-in form `Users::SessionsController#process_action` catches Devise's refusal (`throw :warden` from the `after_set_user` hook) around the whole `create` request, callbacks included: the first `current_user` of the request (a host before_action such as thecore_ui_commons' `reject_locked!`, before `create` even runs) already authenticates the form params (3.7.1; 3.7.0 caught it only inside `create`, so on a real host the 302 remained). It then turns off params authentication for the rest of the request, so a locked user gets exactly the wrong-password answer (401 + `devise.sessions.invalid`), never the failure app's 302, which would tell the password was right. Elsewhere (OAuth callback, open session) the failure app shows `inactive_message` `:user_locked` (`devise.failure.user_locked`, en + it, same words as a wrong password). Never `:locked`: that is Devise's lockable key, and hosts and devise-i18n translate it as "Your account is locked." (the test stores that text to guard it). model_driven_api (API login, each JWT request, OAuth callback), thecore-spot-overrides (M2M token) and thecore_backend_commons (ActionCable) ask the same predicate: keep it the single place where "may this user authenticate" is decided. Before 3.7.0 `locked` was checked nowhere (Odoo #6051). Covered by `test/locked_user_web_login_test.rb`; the dummy app mounts `devise_for :users` and a signed-in-only `root` for it, and its `ApplicationController` reads `current_user` in a before_action as host apps do.

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

## LdapServer#test_connection

`LdapServer#test_connection` binds as `admin_user` and returns an `LdapServer::ConnectionResult` (`success?`, `message`): the server's reason for a refused bind, the `Net::LDAP::Error` message for a host it cannot reach or resolve, and the translated `ldap_server.test_connection.no_admin_credentials` (without contacting it) when either is blank, so anonymous bind always reports a failure here. It never raises a `Net::LDAP::Error` or a `SystemCallError`: net-ldap raises the bare `Errno::ECONNREFUSED` (not a `Net::LDAP::Error`) for a single host that refuses the connection (fixed in 3.6.5). Until 3.6.4 it returned nothing (a refused bind looked like success) and raised for the other two cases; `thecore_ui_rails_admin`'s `test_ldap_server` action shows the result (thecore_ui_rails_admin#17). Covered by `test/ldap_server_test_connection_test.rb`.

## Failed-login limit per IP (3.8.0)

`ThecoreAuthCommons::LoginFailureThrottle` (`lib/thecore_auth_commons/login_failure_throttle.rb`, host Odoo #6052) is inserted by the engine right after `ActionDispatch::RemoteIp`. It watches `POST /users/sign_in`, `POST /api/vN/authenticate` (model_driven_api) and `/users/auth/:provider/callback`. A **failure** is a 401 response (wrong password or locked user, web and API) or an OAuth callback that OmniAuth fails or that sends back to the sign-in form; it is only known from the response, which is why this is a middleware and not a rack-attack rule. After `THECORE_LOGIN_FAILURES_PER_MINUTE` (default 20; `0` turns it off) failures within the current clock minute from one IP, every attempt on those routes from that IP answers 429 with `Retry-After` (JSON under `/api/`, plain text otherwise) until the minute ends. Successful logins are never counted, so users behind one NAT and integrations that sign in often are unaffected: this is the release/3, backward-compatible part of host ADR 0040 point 5; per-account suspension and uniform messages stay on release/4.

The IP is the connection's peer; only when the peer is a trusted proxy (`config.action_dispatch.trusted_proxies`, private networks by default) is it `request.remote_ip`, read from X-Forwarded-For. Rails' `remote_ip` alone believes an X-Forwarded-For sent straight to Puma, so a forged header would get a fresh count per request. Read `PATH_INFO` before calling the app: Warden's failure app rewrites it to `/unauthenticated`.

Counters live in a Redis cache store of their own (`THECORE_LOGIN_THROTTLE_REDIS_URL`, else `REDIS_URL`; namespace `thecore:login_failures`, keys expire in 2 minutes, 0.5 s timeouts). If Redis is unreachable the store logs a warning and the limit fails open. Without a Redis URL the count is in memory per process. In the test environment the default store is a `NullStore` (nothing counted), so host and ATOM suites that fail logins often are unaffected; `test/login_failure_throttle_test.rb` sets a `MemoryStore`.

## LdapServer admin_password is write-only (3.8.0)

`ldap_servers.admin_password` is read only by `Ldap::Authenticator`, the LDAP import and `LdapServer#test_connection` (host Odoo #6084, host ADR 0046 point 10). `LdapServer#serializable_hash` removes it whatever `only`/`except` ask and drops `methods:` (`attributes` and friends would carry it), `LdapServer.ransackable_attributes` leaves it out (no `q[admin_password_*]` oracle, no sort), RailsAdmin edits it as a `:password` field (shown only in the edit form, empty, and a blank submit keeps the stored value) and its index is gone. Not encrypted: that is release/4. Covered by `test/ldap_server_admin_password_test.rb`.
