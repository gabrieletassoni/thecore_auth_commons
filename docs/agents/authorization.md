# Authorization

> Moved verbatim from `CLAUDE.md` on 2026-11-11 (authorization pipeline, permission resolution order, multiple roles). `CLAUDE.md` points here; keep this file accurate whenever the behaviour it describes changes.

## Authorization pipeline

### can + can is always additive

CanCan "last wins" applies **only when `cannot` is involved**. Two `can` rules on the same target are purely additive: calling `can :read, Task` after `can :manage, Task` does **not** reduce the permission — `can?(:manage, Task)` still returns `true`. The only way to revoke a previously granted ability is with an explicit `cannot`.

### Permission resolution order

`Ability#initialize` executes three layers (CanCan **last-wins**):

1. `Abilities::ThecoreAuthCommons` — admin gets `can :manage, :all`; no one can `create Action`; no one can destroy their own User record.
2. All other `Abilities::*` constants defined anywhere in the app (discovered via `Abilities.constants(false)`).
3. **Database permissions** — every `Permission` linked to `user` via `roles → permission_roles → permissions`, ordered by `permission.id` (not by role assignment date or order), translated literally into:

```ruby
self.send(predicate.name.to_sym, action.name.to_sym,
          target.name.classify.constantize rescue target.name.to_sym)
```

The concern is injected at boot via `Ability.send(:include, ThecoreAuthCommonsCanCanCanConcern)` in `after_initialize.rb`. The host app's `Ability` class must exist; this engine does not define it.

### Multiple roles on the same user

When a user has more than one role, **all permissions from all roles are applied** in a single pass ordered by `permission.id`. The date or sequence in which roles were assigned (`RoleUser` records) is irrelevant — only the numeric `id` of the `Permission` row determines application order.

Because all seeded permissions use the `can` predicate, the result is always the **union** of the two roles' permission sets. A `can :read` on a target where another role already granted `can :manage` does not downgrade the ability — CanCan's rules are additive for `can`, and only `cannot` can revoke a prior grant.

**Example — user with both Pianificatore and Manutentore:**

| Target | Pianificatore | Manutentore | Effective |
|--------|--------------|-------------|-----------|
| `Task` | `manage` | `read` | `manage` — `can :read` is redundant after `can :manage` |
| `Report` | `read` | `manage` | `manage` — the higher-id `can :manage` is additive |
| `TimeTable` | — | `manage` | `manage` |
| `Filter` | `manage` | — | `manage` |
| `Project`, `Customer`, `Site`, `Assignment`, `TaskType` | `read` | `read` | `read` |
| `User`, `Unavailability`, `UnavailabilityType` | `read` | — | `read` |
| `PostInterventionActivity` | — | `read` | `read` |

The effective set is `manage` on Task, Filter, Milestone, Link, Report, TimeTable and `read` on all reference models from both roles — regardless of assignment order.
