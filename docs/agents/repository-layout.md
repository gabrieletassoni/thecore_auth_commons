# Repository layout

> Moved verbatim from `CLAUDE.md` on 2026-11-11 (full annotated file tree). `CLAUDE.md` points here; keep this file accurate whenever the behaviour it describes changes.

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
    ldap_server.rb                  # LDAP server config; destroy turns its users into local users
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
  thecore_auth_commons.rb           # Module-level helpers: seed_first_admin, check_user, align_user, generate_secure_password, import_ldap_users_task, entra_id_vars?, google_oauth2_vars?
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
