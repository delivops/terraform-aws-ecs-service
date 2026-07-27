# Changelog

All notable changes to this module are documented here. This project follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the tags produced by
the release workflow are [semantic versions](https://semver.org/).

## [Unreleased]

### Breaking changes

- **Built-in autoscaling removed.** All four mechanisms (`cpu_auto_scaling`,
  `memory_auto_scaling`, `sqs_autoscaling`, `schedule_auto_scaling`) and their
  underlying resources (`aws_appautoscaling_target`, `aws_appautoscaling_policy`,
  `aws_appautoscaling_scheduled_action`, and the SQS CloudWatch metric/composite
  alarms) are gone. **On apply, Terraform will destroy any autoscaling
  resources this module previously created.** Use
  [`delivops/terraform-aws-ecs-custom-autoscaler`](https://github.com/delivops/terraform-aws-ecs-custom-autoscaler)
  (or your own `aws_appautoscaling_*` resources) against the `ecs_service_name`
  output. The `SQS_AUTOSCALING_MIGRATION.md` guide has been removed.
- **ECR image tag mutability now defaults to `IMMUTABLE`** (was `MUTABLE`). The
  attribute change itself is in-place, but afterward a `docker push` that
  overwrites an existing tag (e.g. a moving branch tag such as `main`) will fail.
  Set `ecr = { mutability = "MUTABLE" }` to keep the previous behavior. ECR
  scan-on-push is now enabled by default.
- **Network-mode validations are now enforced.** They were dead code before
  (`tobool(...)` in an unreferenced local), so a config with
  `network_mode = "awsvpc"` and empty `subnet_ids`/`security_group_ids` used to
  apply and now hard-fails at plan (Fargate also requires `awsvpc`). Correct, but
  a previously-"passing" invalid config will now error.
- **`role.attach_execution_policy` now defaults to `true`** (was `false`). The
  module uses the role it creates as the *execution* role, and without
  `AmazonECSTaskExecutionRolePolicy` that role cannot pull from ECR or write
  logs — tasks fail to start with `CannotPullContainerError`. On an existing
  stack this attaches the managed policy to the module-created role on the next
  apply (an added permission, no replacement). Set it to `false` when you supply
  a separate `execution_role_arn`.
- **ALB/NLB target groups now set `target_type` from `network_mode`**
  (`awsvpc` → `ip`, `bridge`/`host` → `instance`) instead of always `ip`. For
  every `awsvpc` service — which is all Fargate services and the module default
  — this resolves to `ip` and is a no-op. Only an EC2 service using
  `bridge`/`host` **with** a load balancer changes, and `target_type` forces
  target group replacement. Such a configuration could not register targets at
  all before, so it was already broken, but check `terraform plan` before
  applying if you run one.
- **`initial_role` must be a full IAM role ARN** (it was already used as an ARN;
  a validation now rejects role names, which never worked).
- **Minimum Terraform version is now `>= 1.9`** (required for cross-variable
  input validation).
- **The `/ecs/<cluster>/<service>/role` SSM parameter and the
  `ssm_role_parameter_name` output are removed**, replaced by the granular
  `/task-role` and `/execution-role` parameters (and their outputs). Consumers
  reading the old `/role` path must switch to `/task-role` / `/execution-role`.

### Added

- `task_role_arn` / `execution_role_arn` — optionally give the task role and the
  execution role distinct identities (both default to the shared role, so
  existing behavior is unchanged). Their ARNs are published to SSM at
  `/ecs/<cluster>/<service>/task-role` and `/execution-role` (new
  `ssm_task_role_parameter_name` / `ssm_execution_role_parameter_name` outputs)
  so a deploy pipeline can consume them. In the common single-role setup both
  parameters carry the same ARN.
- `log_kms_key_id` — optional KMS CMK for the CloudWatch log group.
- `ecr.scan_on_push` (default `true`) and `ecr.kms_key_id` (optional KMS
  encryption; enabling it replaces the repository).
- `gpu_count` — request GPUs for the container via `resourceRequirements`
  (EC2 launch type).

### Fixed

- **First apply with `role.create = true` no longer fails.** The SSM role
  parameters derived their `count` from the resolved role ARN
  (`local.service_role_arn != null`). With `role.create = true` and the role not
  yet in state, `aws_iam_role.this[0].arn` is unknown at plan time, so the count
  was unknown and Terraform refused to plan — meaning a brand-new service using
  `role.create` could never reach its first successful apply. The count is now
  derived from configuration (`var.role.create || var.initial_role != ""`, plus
  the explicit `task_role_arn`/`execution_role_arn` overrides). Present in
  v1.1.1 and earlier.
- **Route53 records no longer crash the plan when the load balancer ARN cannot
  be derived from a listener.** `aws_route53_record.main_alb_record` was created
  whenever `route_53_host_zone_id` and `host` were set, but it reads
  `data.aws_lb.main_alb[0]`, which only existed when `listener_arn` was set —
  so a plan failed with `Invalid index` in two reachable cases: the NLB/TCP path
  (where the ARN arrives as `nlb_arn` and the module creates the listener
  itself) and any configuration setting the Route53 fields without a listener.
  The same mismatch applied to `additional_load_balancers`. Load balancer ARN
  resolution is now centralized in `locals.tf` and covers both the ALB and NLB
  paths, and every consumer (data source, records, and both outputs) shares one
  guard. As a side effect the `load_balancer` output now also populates for
  NLBs, where it previously always returned `null`.
- `launch_type` now honors `ecs_launch_type` (EC2 launches were previously forced
  to `FARGATE` when no capacity provider strategy was set).
- `platform_version` is now `null` rather than `""` for the EC2 launch type,
  where it does not apply.
- Replaced the remaining `lookup()` calls on typed objects
  (`application_load_balancer.stickiness` / `.stickiness_ttl`) with direct
  attribute access, matching the rest of the module.
- The dead `tobool(...)` network-mode validation locals were replaced with real
  validation blocks (see Breaking changes for the behavior impact).
- Container definitions are now built with `jsonencode`, so special characters in
  `container_name`/`container_image` are escaped correctly.
- Examples now pass `terraform validate` (removed duplicate variable declarations
  and an orphaned Cloudflare provider from `multi-dns-example.tf`; renamed a file
  that contained a literal space).

### Internal

- CI now runs `terraform fmt -check -recursive` and `terraform validate` against
  the module and both example roots (`.github/workflows/validate.yaml`).
- `terraform-docs/gh-actions` is pinned to a commit SHA instead of `@main`. The
  action runs with `contents: write` and `git-push`, so a moving ref allowed
  upstream to push arbitrary commits to this repository.
- The docs workflow no longer runs on every branch push (only `pull_request` and
  pushes to `main`), which previously rendered docs twice per PR push.
- Documented that inputs consumed only by the initial task definition
  (`ecs_task_cpu`, `ecs_task_memory`, `network_mode`, `container_name`,
  `container_image`, `gpu_count`) are effectively write-once, because the task
  definition carries `lifecycle { ignore_changes = all }`.

### Notes on earlier releases

- Cloudflare DNS management was removed in an earlier release. If a previous
  version of this module managed a `cloudflare_record` for you, remove it from
  the module's state (e.g. `terraform state rm ...`) and manage the record in
  your own configuration using the `load_balancer` output.
