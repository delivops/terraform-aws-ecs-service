# Changelog

All notable changes to this module are documented here. This project follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the tags produced
by the release workflow are [semantic versions](https://semver.org/).

Releases are cut automatically from conventional-commit messages on merge to
`main`. A breaking change requires `feat!:` or a `BREAKING CHANGE:` footer in
the squash commit; without one the release workflow defaults to a patch bump.

## [3.1.0]

### Added

- **`enable_execute_command = true` on Fargate now requires a task role**, and is
  rejected at plan time when `task_role` supplies neither `create` nor `arn`.

  ECS refuses `CreateService` for a task definition with no `taskRoleArn` when
  execute-command is enabled, and Fargate has no instance role to fall back to.
  Previously the plan succeeded and the apply failed partway through, after the
  task definition had already been registered — and because that task definition
  is write-once, adding the role afterwards produced no new revision, so the
  retry failed the same way. Recovering needed
  `terraform apply -replace=module.<name>.aws_ecs_task_definition.task_definition`.

  EC2 is not covered by the rule: there the instance role stands in for an absent
  task role.

### Changed

- **`enable_execute_command` and `task_role` descriptions now state the IAM
  prerequisite.** ECS Exec tunnels through SSM Session Manager and needs
  `ssmmessages:CreateControlChannel`, `CreateDataChannel`, `OpenControlChannel`
  and `OpenDataChannel` on the task role. The module attaches no policy granting
  them — supply them through `task_role.inline_policy`. Without them the service
  is created and each `execute-command` session fails with `TargetNotConnected`.
  A new README section documents this, and the ALB example now grants the
  permissions it was already implying by enabling the feature.

## [3.0.1]

### Fixed

- Documentation corrections in `README.md`, `CHANGELOG.md` and `CONTRIBUTING.md`.

## [3.0.0]

### Breaking changes

- **The IAM role interface is now two symmetric objects, `task_role` and
  `execution_role`**, each accepting `create`, `arn`, `name`, `inline_policy`
  and `attach_policies`. `execution_role` additionally takes
  `attach_execution_policy`, defaulting to `true`.

  This replaces `role`, `initial_role`, and the flat `task_role_arn` /
  `execution_role_arn` variables, all of which are removed. `create` and `arn`
  are mutually exclusive per role.

  The two roles previously shared one identity, so the container carried the
  ECS agent's startup permissions and neither could be scoped down. They now
  default differently, matching what they are for: the task role starts empty
  because only the application knows what it needs, while a created execution
  role gets `AmazonECSTaskExecutionRolePolicy` because that is the same for
  every service. Previously that attachment was opt-in and off, so
  `role.create = true` produced a role that could not pull an image — tasks
  failed with `CannotPullContainerError`.

  **Migration.** A `moved` block maps `aws_iam_role.this` to
  `aws_iam_role.task`, so an existing module-created role becomes the task role
  and keeps its inline policy and attachments rather than being destroyed.
  Rewrite the inputs:

  ```hcl
  # before
  role         = { create = true, inline_policy = "...", attach_execution_policy = true }
  initial_role = aws_iam_role.existing.arn

  # after
  task_role      = { create = true, inline_policy = "..." }
  execution_role = { create = true }              # or { arn = ... }
  ```

  Setting `execution_role.create = true` adds a second IAM role. To keep one
  shared identity, point both at the same ARN.

- **Outputs `service_role_arn` and `service_role_name` are replaced** by
  `task_role_arn`, `execution_role_arn`, `task_role_name` and
  `execution_role_name`. The ARN outputs report the role in effect whether it
  was created here or supplied.

## [2.4.0]

### Changed

- **`ecr.mutability` now defaults to `IMMUTABLE`** (was `MUTABLE`). Immutable
  tags stop a build from silently replacing an image another deployment is
  already running.

  The attribute change itself is applied in place — the repository is not
  replaced and no images are lost. The consequence is at push time: once the
  repository is immutable, `docker push` **fails** if the tag already exists.
  A pipeline that pushes a moving tag such as `latest`, or a bare branch name
  like `main`, breaks on its next run and must tag uniquely per build (a commit
  SHA, or `main-<sha>`).

  Note the module's own lifecycle policy defaults, `protected_prefixes =
  ["main", "master"]` and `versioned_prefixes = ["v", "sha"]`, describe prefixed
  tags rather than bare ones, which is compatible with immutability.

  Set `ecr = { mutability = "MUTABLE" }` to keep the previous behaviour. A
  validation now rejects any value other than `MUTABLE` or `IMMUTABLE`.

## [2.3.0]

### Changed

- **Minimum Terraform is now `>= 1.9`**, declared in `versions.tf`. Required for
  validation rules that reference other input variables.

- **The network-mode validations are now enforced.** They existed as
  `tobool(...)` expressions in unreferenced locals, so Terraform never evaluated
  them and they never rejected anything. They are now real `validation` blocks
  on `network_mode`:

  - Fargate requires `network_mode = "awsvpc"`.
  - `network_mode = "awsvpc"` requires non-empty `subnet_ids` and
    `security_group_ids`.

  A configuration violating either used to plan and apply; it now fails at plan.
  Both describe configurations AWS rejects anyway, but the failure moves earlier
  and is visible to anyone who had one latent.

## [2.2.0]

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

## [2.1.1]

### Documentation

- Added `CHANGELOG.md`, `CONTRIBUTING.md` and `.github/CODEOWNERS`.
- README corrected: the module was described as Fargate-only despite EC2
  support since v1.2.0; usage examples carried a placeholder `version = "xxx"`;
  HCL blocks were fenced as `python`; the resources list omitted the ECR
  repository and IAM role. Added a section documenting that the initial task
  definition is write-once.
- Rewrote variable descriptions that carried no information
  (`application_load_balancer`, `capacity_provider_strategy`, `desired_count`,
  `service_connect`).

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

- Cloudflare DNS management was removed in v1.0.0. If an earlier version managed
  a `cloudflare_record` for you, remove it from the module's state
  (`terraform state rm ...`) and manage the record in your own configuration
  using the `load_balancer` output.
