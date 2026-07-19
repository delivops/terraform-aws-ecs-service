# Target Group Naming Migration Guide

## Breaking Change

Target group names are now generated with the AWS `name_prefix` feature
instead of a hand-computed `name`. AWS appends its own unique suffix, so the
module no longer builds a name from an md5 hash and a list index.

This is a **breaking change**: on the next `apply`, every module-managed
target group whose name was previously auto-generated will be **replaced**.

## What Changed

| Aspect | Old | New |
|--------|-----|-----|
| Uniqueness | 5-char md5 hash embedded in `name` | AWS-generated suffix via `name_prefix` |
| Position | List index appended (`-tg-<idx>`) | Not needed — suffix guarantees uniqueness |
| Name source | Up to ~20 chars of the service name | First 6 chars of the service name (`name_prefix` max) |
| Listener rule priority | Auto-assigned by AWS (unchanged) | Auto-assigned by AWS (unchanged) |
| Replacement safety | Destroy-then-create | `create_before_destroy = true` |

- Old main name: `myservice-a1b2c-tg`
- New main name: `myserv` + AWS suffix, e.g. `myserv20260719...`

The explicit `target_group_name` override (on both `application_load_balancer`
and `additional_load_balancers[*]`) is **unchanged**. Set it to keep a fixed,
predictable name and avoid replacement.

## Impact

Replacing a target group re-registers the ECS service's targets. With
`create_before_destroy` the new target group is created and wired up before the
old one is destroyed, minimizing disruption, but a brief target
registration/health-check window still applies.

## Migration Options

1. **Accept the replacement** (recommended): run `terraform plan`, confirm the
   only change is target group replacement, then `apply` during a low-traffic
   window.
2. **Pin the current name to avoid replacement**: read the existing target
   group name from state/console and set `target_group_name` to that value on
   the relevant load balancer config. The module then uses `name` instead of
   `name_prefix` and no replacement occurs.
