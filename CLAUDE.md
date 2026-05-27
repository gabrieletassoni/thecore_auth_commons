# CLAUDE.md — thecore_auth_commons

## Purpose

Rails engine that provides authentication (Devise: local, LDAP, OAuth2) and database-driven role-based authorization (CanCanCan) for the Thecore ecosystem.

## Repository layout

```
app/
  controllers/users/
    sessions_controller.rb          # Devise override: local → LDAP fallback login
    omniauth_callbacks_controller.rb# OAuth2 callback handler
  jobs/
    background_ldap_import_job.rb   # ActiveJob wrapper for ThecoreAuthCommons.import_ldap_users_task
  models/
    user.rb                         # Devise model with role/password/admin validations
    role.rb                         # Named role; has many users (through role_users) and permissions
    role_user.rb                    # Join: User ↔ Role
    permission.rb                   # Triplet: predicate + action + target (unique)
    permission_role.rb              # Join: Permission ↔ Role
    predicate.rb                    # Vocabulary: "can" / "cannot"
    action.rb                       # Vocabulary: manage / create / read / update / destroy
    target.rb                       # Vocabulary: "all" + one row per AR model (underscore)
    ldap_server.rb                  # LDAP server config; destroy cascades to associated users
    concerns/api/ldap_server.rb     # model_driven_api JSON attrs for LdapServer
    concerns/rails_admin/ldap_server.rb
    concerns/endpoints/ldap_server.rb
  services/ldap/
    authenticator.rb                # Tries each LdapServer in priority order; calls align_user on success
config/initializers/
  abilities.rb                      # Abilities::ThecoreAuthCommons — hardcoded base rules
  concern_cancancan.rb              # ThecoreAuthCommonsCanCanCanConcern — injects DB permissions into Ability
  after_initialize.rb               # Includes ThecoreAuthCommonsCanCanCanConcern into Ability at boot
  omniauth.rb                       # Registers Entra ID / Google providers when env vars present
lib/
  thecore_auth_commons.rb           # Module-level helpers: check_user, align_user, generate_secure_password, import_ldap_users_task, entra_id_vars?, google_oauth2_vars?
  thecore_auth_commons/engine.rb
  thecore/seed.rb
db/
  seeds.rb                          # Creates first admin; populates predicates/actions/targets
  migrate/
    20160209153816_create_permissions_chain.rb  # Creates predicates, actions, targets, permissions, permission_roles
    20250516074016_create_ldap_servers.rb
    20250516075204_add_auth_source_to_user.rb
    20251216110301_add_ldap_match_fields_to_ldap_server.rb
    20251216111217_add_code_to_ldap_server.rb
```

## Authorization pipeline

`Ability#initialize` executes three layers (CanCan **last-wins**):

1. `Abilities::ThecoreAuthCommons` — admin gets `can :manage, :all`; no one can `create Action`; no one can destroy their own User record.
2. All other `Abilities::*` constants defined anywhere in the app (discovered via `Abilities.constants(false)`).
3. **Database permissions** — every `Permission` linked to `user` via `roles → permission_roles → permissions`, ordered by `id`, translated literally into:

```ruby
self.send(predicate.name.to_sym, action.name.to_sym,
          target.name.classify.constantize rescue target.name.to_sym)
```

The concern is injected at boot via `Ability.send(:include, ThecoreAuthCommonsCanCanCanConcern)` in `after_initialize.rb`. The host app's `Ability` class must exist; this engine does not define it.

## Login flow

`Users::SessionsController#create`:
1. Try Devise local auth (`warden.authenticate`).
2. On failure, try `Ldap::Authenticator#authenticate` — iterates `LdapServer.all` (ordered by `priority`), admin-binds, searches for the user by `auth_field`, then binds as the user DN to verify credentials.
3. On LDAP success, calls `ThecoreAuthCommons.align_user` which find-or-initializes the User, maps LDAP attributes to model fields, assigns roles from `memberOf` groups, and saves with `validate: false`.
4. If both fail, renders the login form with `401`.

## LDAP group → role mapping

`align_user` reads `entry[:memberOf]`, extracts the CN (`group.split(",").first.split("=").last`), and calls `Role.find_or_create_by(name: group_name)`. Groups named `Administrators`, `Domain Admins`, `Schema Admins`, `Enterprise Admins`, `admins`, `administrators` also set `user.admin = true` (only promotes, never demotes an existing admin).

## OAuth2

Providers registered only when the relevant env vars are all present (`entra_id_vars?` / `google_oauth2_vars?`). `check_user` creates the user with `auth_source = provider`, random secure password, and `admin: true`. Uses `omniauth-entra-id` and `omniauth-google-oauth2`.

## Seeds

Run `rails db:seed` (or `rails thecore_auth_commons:db:seed` in host context). Creates:
- Admin user: `admin@BASE_DOMAIN` (env var, default `example.com`) / `ADMIN_PASSWORD` (default `Change#1`)
- `Predicate`: `can`, `cannot`
- `Action`: `manage`, `create`, `read`, `update`, `destroy`
- `Target`: `all` + each `ApplicationRecord.subclass` underscored — so **seeds must run after all models are loaded** (Zeitwerk eager-loads first).

## Key conventions

- **Adding a new permission at runtime**: create `Permission` (predicate + action + target), create `PermissionRole` linking it to a `Role`, assign the `Role` to the `User`. Takes effect on next request (Ability is instantiated per-request).
- **Never delete Action records**: `Abilities::ThecoreAuthCommons` explicitly prevents `create Action` to guard vocabulary integrity.
- **`align_user` saves with `validate: false`**: intentional — LDAP-sourced users may lack fields required by the host app's validations (e.g. `name`, `surname`). Do not change this without checking host-app model constraints.
- **`generate_secure_password`**: always produces a password compliant with the policy (upper + lower + digit + special). Used for LDAP/OAuth users; minimum length 4, default 20.
- **LdapServer destroy cascade**: `after_destroy :remove_users_with_auth_source` deletes all `User` records whose `auth_source == "ldap #{id}"`. Destructive — do not delete server records carelessly in production.
- **`BackgroundLdapImportJob` queue**: `"#{ENV["COMPOSE_PROJECT_NAME"]}_default"` — same pattern as the host app's scheduled jobs.

## Development workflow

- **Update this CLAUDE.md** when adding models, changing the auth flow, adding OAuth providers, or modifying permission resolution logic.
- **Update README.md** when environment variables, setup steps, or user-facing behaviour change.
- The engine has no host-specific logic. Keep it generic; host-app customization belongs in `config/initializers/` of the host app.
