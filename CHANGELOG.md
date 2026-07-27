# Changelog

All notable changes to this module are documented here. This project follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the tags produced
by the release workflow are [semantic versions](https://semver.org/).

Releases are cut automatically from conventional-commit messages on merge to
`main`. A breaking change requires `feat!:` or a `BREAKING CHANGE:` footer in
the squash commit; without one the release workflow defaults to a patch bump.

## [Unreleased]

### Removed

- **Built-in autoscaling.** The `cpu_auto_scaling`, `memory_auto_scaling`,
  `sqs_autoscaling` and `schedule_auto_scaling` variables are gone, along with
  every resource they created: `aws_appautoscaling_target`,
  `aws_appautoscaling_policy`, `aws_appautoscaling_scheduled_action`, and the
  SQS CloudWatch metric and composite alarms.

  **On apply, Terraform destroys any of these the module previously created.**
  A service scaled above its minimum will be scaled back down once the scaling
  policies are gone.

  Attach autoscaling externally against the `ecs_service_name` output — see
  [`delivops/terraform-aws-ecs-custom-autoscaler`](https://github.com/delivops/terraform-aws-ecs-custom-autoscaler)
  — or, to keep the existing resources, remove them from the module's state
  with `terraform state rm` and adopt them in your own configuration before
  upgrading.

  `SQS_AUTOSCALING_MIGRATION.md` and the four autoscaling examples are removed.

## [2.1.0]

### Added

- `log_kms_key_id` — encrypt the CloudWatch log group with a customer-managed
  KMS key. The key policy must allow the CloudWatch Logs service principal in
  the region.
- `ecr.scan_on_push` — image scanning on the created repository. Defaults to
  `true`, matching the ECR submodule's own default, so existing repositories are
  unaffected.
- `ecr.kms_key_id` — customer-managed KMS encryption for the created repository.
  Setting it **replaces the repository**. Empty leaves `encryption_type` unset,
  so no `encryption_configuration` block is emitted.

## [2.0.1]

### Fixed

- Container definitions are built with `jsonencode` instead of string
  interpolation. A `container_image` or `container_name` containing a double
  quote previously produced malformed JSON that the ECS API rejects; a backslash
  was passed through unescaped. Output is otherwise unchanged.

## [2.0.0]

### Breaking changes

- **The `/ecs/<cluster>/<service>/role` SSM parameter and the
  `ssm_role_parameter_name` output are removed.** Terraform destroys that
  parameter on apply. Consumers must read
  `/ecs/<cluster>/<service>/task-role` and `/ecs/<cluster>/<service>/execution-role`
  instead. Where a single shared role is in use, both carry the same ARN, so the
  only change required is the path.

### Added

- `task_role_arn` and `execution_role_arn` — give the task role (application
  permissions) and the execution role (ECR pull, log write, secret fetch)
  distinct identities. Both fall back to the shared role from `role.create` /
  `initial_role`, so a single-role setup is unchanged.
- `ssm_task_role_parameter_name` and `ssm_execution_role_parameter_name` outputs.

## [1.2.0]

### Added

- The EC2 launch type is now usable. `launch_type` honors `ecs_launch_type`
  instead of always sending `FARGATE` when no capacity provider strategy is set,
  and target groups take `target_type` from `network_mode` (`awsvpc` → `ip`,
  `bridge`/`host` → `instance`) instead of always `ip`, which could never
  register EC2 tasks in bridge or host mode.

### Fixed

- `platform_version` is `null` rather than `""` for the EC2 launch type, where
  it does not apply.

### Note

`target_type` forces replacement. Every `awsvpc` service — all Fargate, and the
module default — resolves to `ip` and is unaffected. An EC2 service on
`bridge`/`host` **with** a load balancer will see a target group replacement.

## [1.1.3]

### Fixed

- Route53 records no longer fail the plan when the load balancer ARN cannot be
  derived from a listener ARN. `aws_route53_record.main_alb_record` was created
  whenever `route_53_host_zone_id` and `host` were set but dereferenced a data
  source that only existed when `listener_arn` was set, so the plan failed with
  `Invalid index` for the NLB/TCP path and for any configuration setting the
  Route53 fields without a listener. `additional_load_balancers` had the same
  mismatch. As a side effect the `load_balancer` output now populates for NLBs,
  where it previously always returned `null`.

## [1.1.2]

### Fixed

- A first apply with `role.create = true` no longer fails. The SSM role
  parameter derived its `count` from the resolved role ARN, which is unknown at
  plan time before the role exists, so Terraform refused to plan with
  `Invalid count argument` and a new service using `role.create` could never
  reach its first apply. The count is now derived from configuration.

## Notes on earlier releases

- Cloudflare DNS management was removed in v1.1.0. If an earlier version managed
  a `cloudflare_record` for you, remove it from the module's state
  (`terraform state rm ...`) and manage the record in your own configuration
  using the `load_balancer` output.
