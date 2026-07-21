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
  resources this module previously created.** Attach your own
  `aws_appautoscaling_*` resources to the service using the `ecs_service_name`
  output. The `SQS_AUTOSCALING_MIGRATION.md` guide has been removed.
- **`desired_count` is now authoritative.** It was previously in the service's
  `ignore_changes` so autoscaling could own the running count; with autoscaling
  removed, `var.desired_count` now controls the task count.
- **ECR image tag mutability now defaults to `IMMUTABLE`** (was `MUTABLE`). Set
  `ecr = { mutability = "MUTABLE" }` to keep the previous behavior. ECR
  scan-on-push is now enabled by default.
- **`initial_role` must be a full IAM role ARN** (it was already used as an ARN;
  a validation now rejects role names, which never worked).
- **Minimum Terraform version is now `>= 1.9`** (required for cross-variable
  input validation).

### Added

- `task_role_arn` / `execution_role_arn` — optionally give the task role and the
  execution role distinct identities (both default to the shared role, so
  existing behavior is unchanged).
- `log_kms_key_id` — optional KMS CMK for the CloudWatch log group.
- `ecr.scan_on_push` (default `true`) and `ecr.kms_key_id` (optional KMS
  encryption; enabling it replaces the repository).
- `gpu_count` — request GPUs for the container via `resourceRequirements`
  (EC2 launch type).

### Fixed

- `launch_type` now honors `ecs_launch_type` (EC2 launches were previously forced
  to `FARGATE` when no capacity provider strategy was set).
- Network-mode validations (Fargate requires `awsvpc`; `awsvpc` requires subnets
  and security groups) are now actually enforced — they were dead code before.
- Container definitions are now built with `jsonencode`, so special characters in
  `container_name`/`container_image` are escaped correctly.
- Examples now pass `terraform validate` (removed duplicate variable declarations
  and an orphaned Cloudflare provider from `multi-dns-example.tf`; renamed a file
  that contained a literal space).

### Notes on earlier releases

- Cloudflare DNS management was removed in an earlier release. If a previous
  version of this module managed a `cloudflare_record` for you, remove it from
  the module's state (e.g. `terraform state rm ...`) and manage the record in
  your own configuration using the `load_balancer` output.
