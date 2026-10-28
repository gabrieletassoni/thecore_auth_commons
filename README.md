# thecore_auth_commons

Part of the [Thecore framework](https://github.com/gabrieletassoni/thecore/tree/release/3).

Provides authentication and role-based authorization for Rails applications in the Thecore ecosystem. Integrates Devise (local + LDAP + OAuth2), CanCanCan with database-driven permissions, and LDAP user synchronization.

## Features

- **Devise authentication** — local credentials, LDAP, Microsoft Entra ID (Azure AD), Google OAuth2
- **Role-based authorization** — roles assigned to users; permissions (predicate + action + target) assigned to roles; resolved at runtime by CanCanCan
- **LDAP sync** — import users and groups from one or more LDAP/AD servers; group membership maps to Roles
- **Dynamic SMTP-less** — no restart needed to update auth settings; reads from ThecoreSettings at runtime

## Environment variables

| Variable | Default | Purpose |
|---|---|---|
| `MIN_PASSWORD_LENGTH` | `8` | Minimum password length enforced by Devise |
| `SESSION_TIMEOUT_IN_MINUTES` | `31` | Idle session timeout |
| `ENTRA_CLIENT_ID` | — | Microsoft Entra ID (Azure AD) OAuth2 client ID |
| `ENTRA_CLIENT_SECRET` | — | Microsoft Entra ID OAuth2 client secret |
| `ENTRA_TENANT_ID` | — | Microsoft Entra ID tenant ID |
| `GOOGLE_CLIENT_ID` | — | Google OAuth2 client ID |
| `GOOGLE_CLIENT_SECRET` | — | Google OAuth2 client secret |
| `BASE_DOMAIN` | `example.com` | Used to build the default admin email at seed time |
| `ADMIN_PASSWORD` | — (random) | First admin's password at seed time; when unset the seed generates a random one and writes it to `storage/admin_initial_password` (see Seeding) |

OmniAuth providers are registered only when their respective env vars are all present.

## Authorization model

```
User ──< RoleUser >── Role ──< PermissionRole >── Permission
                                                       │
                                                 ┌─────┼─────┐
                                              Predicate Action Target
```

### Tables

| Table | Content |
|---|---|
| `predicates` | `can`, `cannot` |
| `actions` | `manage`, `create`, `read`, `update`, `destroy` |
| `targets` | `all`, plus one row per `ApplicationRecord` subclass (underscore-cased) |
| `permissions` | Combination of one predicate + one action + one target (unique triplet) |
| `permission_roles` | Join between `permissions` and `roles` |
| `roles` | Named roles |
| `role_users` | Join between `roles` and `users` |

### How permissions are resolved

At login, `Ability#initialize` runs three layers in order (CanCan **last-wins**):

1. `Abilities::ThecoreAuthCommons` — hardcoded base: admins get `can :manage, :all`; nobody can `create Action`; no one can destroy their own User record.
2. All other `Abilities::*` modules defined in the host app or other engines.
3. Database-driven permissions — every `Permission` linked to the current user (via their roles) is translated into a live CanCan call:

```ruby
self.send(predicate.name, action.name, target.name.classify.constantize)
# e.g.  can(:manage, Task)  /  cannot(:destroy, User)
```

Permissions are applied in ascending `id` order, so a later `cannot` can override an earlier `can`.

### Seeding

`db/seeds.rb` populates the three vocabulary tables on first run:

```ruby
predicates: [:can, :cannot]
actions:    [:manage, :create, :read, :update, :destroy]
targets:    ["all"] + ApplicationRecord.subclasses.map { |m| m.to_s.underscore }
```

It also creates the first admin user, `admin@BASE_DOMAIN`, only if the database has no admin yet (existing admins are never touched). Its password is `ADMIN_PASSWORD` when set. Otherwise the seed generates a random one and writes it to `<Rails.root>/storage/admin_initial_password` with mode `0600`; the log gets one line saying where it is, never the password. In a `thecore_devcontainer` deployment that's `/root/persistence/${COMPOSE_PROJECT_NAME}/storage/admin_initial_password` on the host, or `docker compose exec backend cat storage/admin_initial_password`. After the first login change the password and delete the file. An existing file is never overwritten: if it's there, the admin is not created and the log says to delete the file and seed again. Until 3.6.1 the fallback was the fixed `Change#1`.

To add a permission via console:

```ruby
perm = Permission.create!(
  predicate: Predicate.find_by(name: "can"),
  action:    Action.find_by(name: "manage"),
  target:    Target.find_by(name: "task")
)
role = Role.find_or_create_by(name: "manager")
PermissionRole.create!(role: role, permission: perm)
user.roles << role
```

## Authentication flow

### Local + LDAP fallback

`Users::SessionsController#create` tries Devise first; if that fails it tries `Ldap::Authenticator`. On successful LDAP auth the user is created/updated via `ThecoreAuthCommons.align_user` and signed in.

### LDAP servers (`LdapServer` model)

Multiple servers are supported, ordered by `priority` (ascending). Each server configures:

- `host`, `port`, `use_ssl`, `base_dn`, `admin_user`, `admin_password`
- `auth_field` — LDAP attribute used as login (e.g. `mail`, `sAMAccountName`)
- `name`, `surname`, `phone`, `code` — LDAP attributes mapped to User fields

On LDAP login or import, `memberOf` groups are read; matching group names become `Role` records assigned to the user. Groups named `Administrators`, `Domain Admins`, `Schema Admins`, `Enterprise Admins`, `admins`, or `administrators` also grant `user.admin = true`.

Deleting a `LdapServer` record keeps all users whose `auth_source` is `"ldap #{id}"` — same record, same roles — and turns them into local users (`auth_source = "local"`). To log in again they need a local password, set by hand.

### Background LDAP import

`BackgroundLdapImportJob` calls `ThecoreAuthCommons.import_ldap_users_task`, which iterates all `LdapServer` records and upserts matching users. Uses the same queue name as the host app (`#{COMPOSE_PROJECT_NAME}_default`).

### OAuth2 (Entra ID / Google)

Handled by `Users::OmniauthCallbacksController`. On callback, `ThecoreAuthCommons.check_user` finds the user by the provider-verified email or creates them (random secure password, `auth_source` `'google'` or `'microsoft'`, no admin, no roles: an administrator assigns those). An existing user's password, admin flag and `auth_source` are never changed by an OAuth login.

## Password policy

Passwords must contain at least one uppercase letter, one lowercase letter, one digit, and one special character. Minimum length is controlled by `MIN_PASSWORD_LENGTH`.

`ThecoreAuthCommons.generate_secure_password(length = 20)` generates a compliant random password (used for LDAP/OAuth users who never type their password locally).

## User model validations

- Cannot remove admin flag from the last remaining admin.
- Cannot lock the last non-locked account.
- Email must match a standard address format and be unique (case-insensitive).
