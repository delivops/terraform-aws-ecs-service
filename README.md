[![DelivOps banner](https://raw.githubusercontent.com/delivops/.github/main/images/banner.png?raw=true)](https://delivops.com)

# AWS ECS Service Terraform Module

This Terraform module deploys an ECS service on Fargate or EC2, with support for load balancing and custom deployment configurations.

## Features

- Creates an ECS service with the Fargate or EC2 launch type
- Configurable load balancer target group with health checks
- Support for host-based and path-based routing rules
- CloudWatch logging integration, with optional KMS encryption
- Separate task and execution roles, published to SSM for a deploy pipeline
- Optional Terraform-managed task definition template that the deploy pipeline copies, swapping only the image, with containers generated from `ecs-deploy-action`-style keys: log config, secrets, secret-file init containers, OTel/Fluent Bit collectors, sidecars and volumes
- Deployment circuit breaker and CloudWatch alarms integration
- Route53 DNS record management (other providers, e.g. Cloudflare, can be wired via the `load_balancer` output)

## Resources Created

- ECS Service (Fargate or EC2)
- ECS Task Definition (initial revision only — see below)
- ECS Task Definition template, in its own family (optional)
- Application/Network Load Balancer Target Group (optional)
- Load Balancer Listener Rules (host-based and path-based)
- CloudWatch Log Group
- CloudWatch Alarms for deployment circuit breaker (optional)
- ECR Repository (optional)
- IAM role (optional)
- Route53 DNS Records (optional)

## The initial task definition is write-once

The module registers a task definition to bootstrap the service, then steps out
of the way: `aws_ecs_task_definition` carries `lifecycle { ignore_changes = all }`
and the service ignores `task_definition` changes, so the running revision is
owned by your deploy pipeline.

The practical consequence is that these inputs only affect the **first**
revision. On an existing service, changing them produces a clean plan and no
actual change — update them in the pipeline that registers the task definition:

| Input | Owned afterwards by |
|---|---|
| `ecs_task_cpu`, `ecs_task_memory` | CI task definition |
| `container_name`, `container_image` | CI task definition |
| `network_mode` | CI task definition (also selects target group `target_type`) |
| `task_role`, `execution_role` | CI, via the SSM parameters below |

Inputs on the *service* — load balancer wiring, Service Connect, placement,
deployment settings — reconcile normally. The exception is `desired_count`,
which is also ignored so an external autoscaler can own the running count.

## Task definition template

For teams that want every task setting in Terraform but don't want code deploys
to run Terraform, `task_definition_template` keeps a second, fully managed task
definition in its own family, `<cluster>_<service>-template`. The image tag is
then the only thing the pipeline decides.

```hcl
module "api" {
  source = "delivops/ecs-service/aws"
  # ... cluster, service, networking ...

  container_name  = "app"
  container_image = "my-repo:template" # placeholder, replaced on every deploy
  execution_role  = { create = true }

  task_definition_template = {
    enabled       = true
    cpu           = 512
    memory        = 1024
    replica_count = 2

    port         = 8080
    envs         = { LOG_LEVEL = "info" }
    secrets      = { DB_PASSWORD = "arn:aws:secretsmanager:...:secret:db-AbCdEf" }
    health_check = { command = "curl -f http://localhost:8080/health || exit 1" }

    otel_collector = {}
    sidecars = [
      { name = "cache", image = "redis:7", port = 6379, memory_reservation = 128 },
    ]
  }
}
```

### Generated containers

The keys mirror the task config YAML of
[`delivops/ecs-deploy-action`](https://github.com/delivops/ecs-deploy-action)
and produce the same container definitions, so a service can move from one to
the other without its running task definition changing. The module fills in
what the action used to: the log group (`/ecs/<cluster>/<service>`) and region,
stream prefixes, the ECR registry for collector images, and the init containers
and volumes behind `secret_files` and `writable_dirs`.

| Key | Generates |
|---|---|
| `port`, `additional_ports`, `app_protocol` | `portMappings`; the main port is named `default`. With `network_mode = "bridge"`, `hostPort` is `0`. |
| `command`, `entrypoint`, `stop_timeout`, `health_check`, `linux_parameters` | The matching container fields. `health_check.command` runs through `CMD-SHELL`. `shared_memory_size` and `devices` are dropped on Fargate. |
| `envs` | `environment` |
| `secrets` | One secret per entry: env var name ⇒ secret ARN, reading the JSON key of the same name (`<arn>:<name>::`). |
| `secrets_envs` | `[{ id = <secret ARN>, values = [<JSON keys>] }]`, one env var per key. Mutually exclusive with `secrets`. |
| `secrets_value_from` | Env var name ⇒ `valueFrom` used verbatim: an SSM parameter, or a whole secret. |
| `secret_files` | An `init-container-for-secret-files` container that downloads each secret to `secrets_files_path` on the `shared-volume` volume, and a `SUCCESS` dependency on it. |
| `readonly_root_filesystem`, `writable_dirs` | `readonlyRootFilesystem`, and a `writable-<path>` volume mounted per directory. Both apply to every container the application owns: its init container, fluent-bit and otel-collector. |
| `otel_collector` | An `otel-collector` container on ports 4317 (gRPC) and 4318. With no `image_name` or `image`, it runs the public ADOT image with its config read from the SSM parameter `ssm_name`. |
| `fluent_bit_collector` | A `fluent-bit` container from `image_name` or `image`, one of which is required. The application logs through FireLens and waits for it to start. `ecs_log_metadata` is a bool. |
| `sidecars` | One container each, with its own copy of the keys above, isolated from the application. A sidecar's `secret_files` get a `<name>-secret-init` container and a `<name>-secrets` volume; its `writable_dirs` get `<name>-writable-<path>` volumes. `readonly_root_filesystem` falls back to the application's value. Logs go to the stream prefix `log_stream_prefix`, which defaults to the sidecar's name. |
| `volumes` | Extra task volumes (`host_path` or `efs_volume_configuration`), alongside the generated ones. |
| `container_definitions` | Extra containers in ECS API shape, appended as-is. |
| `container_overrides` | Container name ⇒ ECS API fields merged over that generated container (e.g. `ulimits`, `dockerLabels`). Every key must name a generated container. |

`image_name` on either collector is a repository in the deploying account's ECR
registry; `image` is a full image reference. Plans fail on the mistakes ECS would
otherwise reject at registration:
- Container, volume and port mapping names must be unique across the task.
- Port mapping names follow ECS's rules: lowercase, starting with a letter, at
  most 64 characters. That covers `additional_ports` keys and a sidecar's
  `<name>-<port>-tcp`, so a sidecar with a `port` needs a lowercase name.
- `app_protocol` is `http`, `http2`, `grpc` or `tcp`.

Coming from the action's YAML:

- `envs`, `secrets` and `additional_ports` are maps rather than lists of
  single-key maps. Env values are strings. The action rendered YAML booleans
  with Python's capitalization, so an unquoted `true` reached the container as
  `"True"`; write `"True"` to keep the value unchanged.
- `cpu_arch` is `cpu_architecture`, and `ephemeral_storage` is
  `ephemeral_storage_gib`.
- `services_overrides` and `envs_from_files` are plain Terraform: `for_each`
  with `merge()`, and `file()` or tfvars.
- A `secrets_envs` entry with only a `name`, where the action discovered the
  secret's keys at deploy time, has no equivalent. List the keys under `values`.
- The action ignored `secrets_envs` when `secrets` was also set. The module
  rejects that combination.
- `launch_type`, `network_mode` and the role ARNs come from the module's
  `ecs_launch_type`, `network_mode`, `task_role` and `execution_role`.

`runtime_platform` (`cpu_architecture`, `operating_system_family`) is only
declared on Fargate, like the action. The template requires an execution role.

### Pipeline contract

Every change to the template registers a new revision in the template family.
Nothing reaches running tasks until the next deploy. The module publishes:

| Parameter | Value |
|---|---|
| `/ecs/<cluster>/<service>/task-definition-template` | The template family |
| `/ecs/<cluster>/<service>/replica-count` | `replica_count`; absent when null, i.e. for autoscaled services |

A deploy:

1. Reads the family from the parameter.
2. Describes the family's latest ACTIVE revision
   (`aws ecs describe-task-definition --task-definition <family>`).
3. Replaces the `image` of the `container_name` container with the build being
   deployed.
4. Removes the read-only fields `taskDefinitionArn`, `revision`, `status`,
   `requiresAttributes`, `compatibilities`, `registeredAt`, `registeredBy`,
   `deregisteredAt` and `deleteRequestedAt`, and sets `family` to
   `<cluster>_<service>`.
5. Registers the result and updates the service to the new revision, passing
   `--desired-count` only when the replica-count parameter exists.

A reference implementation (AWS CLI and `jq`; the deploy role needs
`ssm:GetParameter`, `ecs:DescribeTaskDefinition`, `ecs:RegisterTaskDefinition`,
`iam:PassRole`, `ecs:UpdateService` and `ecs:DescribeServices`):

```bash
#!/bin/bash
# Usage: deploy-from-template.sh <cluster> <service> <image> [container=app]
set -euo pipefail
CLUSTER=$1 SERVICE=$2 IMAGE=$3 CONTAINER=${4:-app}
PREFIX="/ecs/$CLUSTER/$SERVICE"

FAMILY=$(aws ssm get-parameter --name "$PREFIX/task-definition-template" --query Parameter.Value --output text)
# A missing replica-count parameter means the desired count is left alone; any
# other failure (e.g. access denied) must not silently skip it.
if ! REPLICAS=$(aws ssm get-parameter --name "$PREFIX/replica-count" --query Parameter.Value --output text 2>ssm-error.txt); then
  grep -q ParameterNotFound ssm-error.txt || { cat ssm-error.txt >&2; exit 1; }
  REPLICAS=""
fi

aws ecs describe-task-definition --task-definition "$FAMILY" --query taskDefinition --output json |
  jq --arg family "${CLUSTER}_${SERVICE}" --arg container "$CONTAINER" --arg image "$IMAGE" '
    if ([.containerDefinitions[] | select(.name == $container)] | length) != 1
    then error("template has no container named \($container)") else . end
    | .family = $family
    | .containerDefinitions |= map(if .name == $container then .image = $image else . end)
    | del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .compatibilities,
          .registeredAt, .registeredBy, .deregisteredAt, .deleteRequestedAt)
  ' > task-definition.json

ARN=$(aws ecs register-task-definition --cli-input-json file://task-definition.json \
  --query taskDefinition.taskDefinitionArn --output text)
aws ecs update-service --cluster "$CLUSTER" --service "$SERVICE" --task-definition "$ARN" \
  ${REPLICAS:+--desired-count "$REPLICAS"} >/dev/null

# `aws ecs wait services-stable` gives up after 10 minutes; allow up to 30.
STABLE=0
for _ in 1 2 3; do
  aws ecs wait services-stable --cluster "$CLUSTER" --services "$SERVICE" && { STABLE=1; break; }
done
[ "$STABLE" = 1 ] || { echo "service not stable after 30 minutes" >&2; exit 1; }
DEPLOYED=$(aws ecs describe-services --cluster "$CLUSTER" --services "$SERVICE" \
  --query 'services[0].deployments[?status==`PRIMARY`].taskDefinition | [0]' --output text)
[ "$DEPLOYED" = "$ARN" ] || { echo "deployment rolled back: running $DEPLOYED, expected $ARN" >&2; exit 1; }
echo "deployed $ARN"
```

The write-once task definition and the service lifecycle described above are
unchanged: the service family is still owned by the pipeline, and the template
only feeds it. Tags are not copied; the service's tags propagate to tasks as
usual.

The template revision is replaced with `create_before_destroy`, so the family
always has an ACTIVE revision for a deploy that runs during an apply.

Every argument of a task definition forces replacement, so a plan that proposes
replacing the template on each run with no configuration change means ECS
returned a container definition in a different shape than the one generated.
Set that field in its returned shape through `container_overrides`.

## Usage

```hcl

################################################################################
# AWS ECS-SERVICE (without ALB)
################################################################################

module "demo_ecs_service" {
  source  = "delivops/ecs-service/aws"
  version = "~> 3.0"

  ecs_cluster_name   = var.cluster_name
  ecs_service_name   = "demo"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

}
```

```hcl

################################################################################
# AWS ECS-SERVICE (with ALB)
################################################################################

module "alb_ecs_service" {
  source  = "delivops/ecs-service/aws"
  version = "~> 3.0"
  ecs_cluster_name   = var.cluster_name
  ecs_service_name   = "alb"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  application_load_balancer = {
    enabled           = true
    container_port    = 80
    listener_arn      = var.listener_arn
    host              = "demo.internal.delivops.com"
    path              = "/*"
    health_check_path = "/health"
  }
}
```

```hcl

################################################################################
# AWS ECS-SERVICE (with ALB and Route53 DNS)
################################################################################

module "alb_ecs_service_with_route53" {
  source  = "delivops/ecs-service/aws"
  version = "~> 3.0"
  ecs_cluster_name   = var.cluster_name
  ecs_service_name   = "route53-demo"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  application_load_balancer = {
    enabled               = true
    container_port        = 80
    listener_arn          = var.listener_arn
    host                  = "api.example.com"
    path                  = "/*"
    health_check_path     = "/health"
    route_53_host_zone_id = var.route_53_zone_id
  }
}
```

```hcl

################################################################################
# AWS ECS-SERVICE (with ALB, DNS managed in Cloudflare outside the module)
################################################################################

module "alb_ecs_service" {
  source  = "delivops/ecs-service/aws"
  version = "~> 3.0"
  ecs_cluster_name   = var.cluster_name
  ecs_service_name   = "cloudflare-demo"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  application_load_balancer = {
    enabled           = true
    container_port    = 80
    listener_arn      = var.listener_arn
    host              = "api.example.com"
    path              = "/*"
    health_check_path = "/health"
  }
}

# Cloudflare is NOT managed by the module. Configure the provider and create
# records in your own configuration using the module's `load_balancer` output.
resource "cloudflare_record" "api" {
  zone_id = var.cloudflare_zone_id
  name    = "api.example.com"
  content = module.alb_ecs_service.load_balancer.main.dns_name
  type    = "CNAME"
  proxied = true
}
```

## Task and execution roles

The two roles do different jobs, so the module configures them separately.

- **Task role** — what the container assumes for application work (S3, SQS, …).
  Inherently per-service, so it starts with no permissions.
- **Execution role** — what the ECS agent assumes to *start* the task: pull from
  ECR, write logs, fetch secrets. Effectively the same for every service, so
  when the module creates one it attaches `AmazonECSTaskExecutionRolePolicy`
  automatically.

Each role is independently created here, supplied by ARN, or left absent:

```hcl
task_role = {
  create        = true
  inline_policy = jsonencode({ ... })   # this service's own permissions
  attach_policies = ["arn:aws:iam::aws:policy/..."]
}

execution_role = {
  arn = aws_iam_role.shared_execution.arn   # one shared role across services
}
```

| Field | `task_role` | `execution_role` | Default |
|---|---|---|---|
| `create` | ✓ | ✓ | `false` |
| `arn` | ✓ | ✓ | `""` |
| `name` | ✓ | ✓ | `"<cluster>_<service>"` (execution role suffixed `_execution`) |
| `inline_policy` | ✓ | ✓ | `""` |
| `attach_policies` | ✓ | ✓ | `[]` |
| `attach_execution_policy` | — | ✓ | `true` |

`create` and `arn` are mutually exclusive; setting both is a validation error
rather than a silent precedence rule.

`AmazonECSTaskExecutionRolePolicy` does **not** grant access to secrets. If the
task definition references `secrets` from SSM Parameter Store or Secrets
Manager, add `ssm:GetParameters` / `secretsmanager:GetSecretValue` through
`execution_role.inline_policy`.

The effective ARNs are exposed as the `task_role_arn` and `execution_role_arn`
outputs, and published to SSM (below) for a deploy pipeline.

## ECS Exec

`enable_execute_command = true` requires a task role. ECS refuses to create the
service without one — on Fargate, where there is no instance role to fall back
to, the module rejects that combination at plan time:

```
enable_execute_command on Fargate requires a task role: ...
```

Supplying a task role satisfies ECS, but not the feature: ECS Exec tunnels
through SSM Session Manager, and the module attaches nothing granting it. Add
the permissions yourself:

```hcl
task_role = {
  create = true
  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel",
      ]
      Resource = "*"
    }]
  })
}
```

Without them the service comes up and `execute-command` fails per session with
`TargetNotConnected`.

If an apply already failed at `CreateService` for a missing task role, adding one
is not enough on its own. The task definition was registered in the same apply
and is write-once (above), so the corrected config produces no new revision and
the retry recreates the service against the same role-less one. Force a new
revision:

```bash
terraform apply -replace=module.<name>.aws_ecs_task_definition.task_definition
```

## SSM Parameters

The module publishes per-service metadata to SSM Parameter Store so a deploy
pipeline can read it without reconstructing values:

| Parameter | Value | Notes |
|---|---|---|
| `/ecs/<cluster>/<service>/task-role` | Task role ARN (application permissions) | Not created when no task role exists. |
| `/ecs/<cluster>/<service>/execution-role` | Execution role ARN (ECR pull, log write, secret fetch) | Not created when no execution role exists. |
| `/ecs/<cluster>/<service>/task-definition-template` | Task definition template family | Only created when `task_definition_template.enabled`. See [Task definition template](#task-definition-template). |
| `/ecs/<cluster>/<service>/replica-count` | Desired count for the deploy pipeline | Only created when `task_definition_template.enabled` and `replica_count` is set. |

The parameter names are exposed via the `ssm_task_role_parameter_name` and
`ssm_execution_role_parameter_name` outputs. When a single shared role is used
both parameters carry the same ARN.

Tags are **not** published to SSM. Tasks are tagged by tagging the ECS service
(`{ Application } + var.tags`) together with `propagate_tags = "SERVICE"`, so
tasks inherit the service tags directly — the deploy pipeline does not need to
read tags from SSM.

## DNS Configuration

This module manages **Route53** DNS records natively. Cloudflare (or any other
DNS provider) is intentionally **not** managed by the module — it exposes the
ALB DNS details so you can create those records in your own configuration.

### Route53 DNS Records
- Set `route_53_host_zone_id` to your Route53 hosted zone ID
- The module creates an A record with an alias to the load balancer
- Supports both main and additional load balancers

### Cloudflare / external DNS
The module does not configure a Cloudflare provider or create Cloudflare
records. This keeps the module free of an embedded provider block, so it can be
used with `count`, `for_each`, and `depends_on`.

To point a Cloudflare (or other) record at the service, use the `load_balancer`
output, which exposes the ALB `dns_name`, `zone_id`, and `host` for the main and
any additional load balancers:

```hcl
resource "cloudflare_record" "api" {
  zone_id = var.cloudflare_zone_id
  name    = "api.example.com"
  content = module.ecs_service.load_balancer.main.dns_name
  type    = "CNAME"
  proxied = true
}
```

## Autoscaling

Autoscaling is not managed by this module. Attach it externally against the
`ecs_service_name` output — for example with
[`delivops/terraform-aws-ecs-custom-autoscaler`](https://github.com/delivops/terraform-aws-ecs-custom-autoscaler),
or your own `aws_appautoscaling_target` and `aws_appautoscaling_policy`
resources.

`desired_count` is in the service's `ignore_changes`, so an external autoscaler
owns the running task count without Terraform reverting it. `var.desired_count`
only seeds the count at service creation.

## Notes

- Task CPU and memory default to 256 units / 512 MiB, configurable via `ecs_task_cpu` and `ecs_task_memory`
- The default container image is `nginx:latest`, overridable via `container_image`
- The initial task definition sets no `runtime_platform`, so it uses the ECS default (Linux/X86_64). Set the architecture in the CI-managed task definition if you need ARM64, or with `task_definition_template.cpu_architecture` when using the template.
- The module ignores changes to the task definition to support external (CI-managed) deployments
- An NLB must be created outside this module. Pass its ARN as `nlb_arn`, set `protocol = "TCP"` and `health_check_protocol = "TCP"`; the module creates the listener and can still manage the Route53 alias record for it.

## License

This module is released under the MIT License.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.16.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_ecr"></a> [ecr](#module\_ecr) | terraform-aws-modules/ecr/aws | 2.3.0 |

## Resources

| Name | Type |
|------|------|
| [aws_alb_target_group.target_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/alb_target_group) | resource |
| [aws_alb_target_group.target_group_additional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/alb_target_group) | resource |
| [aws_cloudwatch_log_anomaly_detector.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_anomaly_detector) | resource |
| [aws_cloudwatch_log_group.ecs_log_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ecs_service.ecs_service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.task_definition](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_ecs_task_definition.template](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_iam_role.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.execution_inline](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.task_inline](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.execution_attached](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.execution_managed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.task_attached](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lb_listener.tcp_listener](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener.tcp_listener_additional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener_rule.rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule) | resource |
| [aws_lb_listener_rule.rule_additional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule) | resource |
| [aws_route53_record.additional_alb_records](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.main_alb_record](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_ssm_parameter.execution_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.task_definition_template](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.task_definition_template_replica_count](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.task_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_ecs_cluster.ecs_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ecs_cluster) | data source |
| [aws_lb.additional_albs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/lb) | data source |
| [aws_lb.main_alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/lb) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_service_discovery_http_namespace.namespace](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/service_discovery_http_namespace) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_load_balancers"></a> [additional\_load\_balancers](#input\_additional\_load\_balancers) | Additional load balancers configuration | <pre>list(object({<br/>    enabled                          = optional(bool, false)<br/>    container_port                   = optional(number, 80)<br/>    listener_arn                     = optional(string, "")<br/>    nlb_arn                          = optional(string, "")<br/>    nlb_port                         = optional(number, 80)<br/>    host                             = optional(string, "")<br/>    path                             = optional(string, "/*")<br/>    protocol                         = optional(string, "HTTP")<br/>    health_check_path                = optional(string, "/health")<br/>    health_check_matcher             = optional(string, "200")<br/>    health_check_interval_sec        = optional(number, 30)<br/>    health_check_timeout_sec         = optional(number, 10)<br/>    health_check_threshold_healthy   = optional(number, 2)<br/>    health_check_threshold_unhealthy = optional(number, 5)<br/>    health_check_protocol            = optional(string, "HTTP")<br/>    health_check_port                = optional(string, "traffic-port")<br/>    stickiness                       = optional(bool, false)<br/>    stickiness_ttl                   = optional(number, 300)<br/>    stickiness_type                  = optional(string, "app_cookie")<br/>    cookie_name                      = optional(string, "")<br/>    action_type                      = optional(string, "forward")<br/>    target_group_name                = optional(string, "")<br/>    deregister_deregistration_delay  = optional(number, 60)<br/>    route_53_host_zone_id            = optional(string, "")<br/>  }))</pre> | `[]` | no |
| <a name="input_application_load_balancer"></a> [application\_load\_balancer](#input\_application\_load\_balancer) | Primary load balancer for the service: target group, health checks, listener rule (host/path routing or fixed-response), stickiness, and an optional Route53 alias record. Set enabled = true to attach the service to an existing ALB listener, or protocol = "TCP" with nlb\_arn to have the module create an NLB listener. | <pre>object({<br/>    enabled                          = optional(bool, false)<br/>    container_port                   = optional(number, 80)<br/>    listener_arn                     = optional(string, "")<br/>    nlb_arn                          = optional(string, "")<br/>    nlb_port                         = optional(number, 80)<br/>    host                             = optional(string, "")<br/>    path                             = optional(string, "/*")<br/>    protocol                         = optional(string, "HTTP")<br/>    health_check_path                = optional(string, "/health")<br/>    health_check_matcher             = optional(string, "200")<br/>    health_check_interval_sec        = optional(number, 30)<br/>    health_check_timeout_sec         = optional(number, 10)<br/>    health_check_threshold_healthy   = optional(number, 2)<br/>    health_check_threshold_unhealthy = optional(number, 5)<br/>    health_check_protocol            = optional(string, "HTTP")<br/>    health_check_port                = optional(string, "traffic-port")<br/>    stickiness                       = optional(bool, false)<br/>    stickiness_ttl                   = optional(number, 300)<br/>    cookie_name                      = optional(string, "")<br/>    stickiness_type                  = optional(string, "app_cookie")<br/>    action_type                      = optional(string, "forward")<br/>    target_group_name                = optional(string, "")<br/>    deregister_deregistration_delay  = optional(number, 60)<br/>    route_53_host_zone_id            = optional(string, "")<br/>  })</pre> | `{}` | no |
| <a name="input_assign_public_ip"></a> [assign\_public\_ip](#input\_assign\_public\_ip) | Assign public IP to ECS tasks | `bool` | `false` | no |
| <a name="input_capacity_provider_strategy"></a> [capacity\_provider\_strategy](#input\_capacity\_provider\_strategy) | Name of an existing ECS capacity provider for the service. When set, the service uses it instead of a plain launch\_type. Leave empty to use ecs\_launch\_type directly. | `string` | `""` | no |
| <a name="input_container_image"></a> [container\_image](#input\_container\_image) | Docker image for the container | `string` | `"nginx:latest"` | no |
| <a name="input_container_name"></a> [container\_name](#input\_container\_name) | Name of the container | `string` | `"app"` | no |
| <a name="input_deployment"></a> [deployment](#input\_deployment) | Deployment configuration for the ECS service | <pre>object({<br/>    min_healthy_percent       = optional(number, 100)<br/>    max_healthy_percent       = optional(number, 200)<br/>    circuit_breaker_enabled   = optional(bool, true)<br/>    rollback_enabled          = optional(bool, true)<br/>    cloudwatch_alarm_enabled  = optional(bool, false)<br/>    cloudwatch_alarm_rollback = optional(bool, true)<br/>    cloudwatch_alarm_names    = optional(list(string), [])<br/>  })</pre> | `{}` | no |
| <a name="input_desired_count"></a> [desired\_count](#input\_desired\_count) | Number of tasks at service creation. Not reconciled afterwards — desired\_count is in the service's ignore\_changes, so an autoscaler or deploy pipeline can own the running count without Terraform reverting it. | `number` | `1` | no |
| <a name="input_ecr"></a> [ecr](#input\_ecr) | ECR repository configuration. mutability = IMMUTABLE rejects a push that would overwrite an existing tag, so tags must be unique per build (a commit SHA rather than a moving branch name). | <pre>object({<br/>    create_repo         = optional(bool, false)<br/>    repo_name           = optional(string, "")<br/>    mutability          = optional(string, "IMMUTABLE")<br/>    scan_on_push        = optional(bool, true)<br/>    kms_key_id          = optional(string, "") # KMS key ARN. Empty uses AES256. Setting this replaces the repository.<br/>    untagged_ttl_days   = optional(number, 7)<br/>    tagged_ttl_days     = optional(number, 7)<br/>    protected_prefixes  = optional(list(string), ["main", "master"])<br/>    protected_retention = optional(number, 999999) # Keep nearly forever<br/>    versioned_prefixes  = optional(list(string), ["v", "sha"])<br/>    versioned_retention = optional(number, 30) # How many versioned tags to keep<br/>  })</pre> | `{}` | no |
| <a name="input_ecs_cluster_name"></a> [ecs\_cluster\_name](#input\_ecs\_cluster\_name) | Name of the ECS cluster | `string` | n/a | yes |
| <a name="input_ecs_launch_type"></a> [ecs\_launch\_type](#input\_ecs\_launch\_type) | Launch type for the ECS service (FARGATE or EC2) | `string` | `"FARGATE"` | no |
| <a name="input_ecs_service_name"></a> [ecs\_service\_name](#input\_ecs\_service\_name) | Name of the ECS service | `string` | n/a | yes |
| <a name="input_ecs_task_cpu"></a> [ecs\_task\_cpu](#input\_ecs\_task\_cpu) | CPU units for the ECS task | `number` | `256` | no |
| <a name="input_ecs_task_memory"></a> [ecs\_task\_memory](#input\_ecs\_task\_memory) | Memory for the ECS task in MiB | `number` | `512` | no |
| <a name="input_enable_execute_command"></a> [enable\_execute\_command](#input\_enable\_execute\_command) | Enable ECS Exec (aws ecs execute-command) on the service. Requires a task role: ECS rejects CreateService without one, and that role needs the ssmmessages permissions ECS Exec runs on — this module attaches no policy granting them. Set on the service rather than the task definition, so unlike the task definition inputs it reconciles normally. | `bool` | `false` | no |
| <a name="input_execution_role"></a> [execution\_role](#input\_execution\_role) | IAM role the ECS agent assumes to start the task — ECR pull, log write, secret fetch. Either create it here (create = true) or supply an existing one (arn); a single execution role shared across services is a common pattern. When created, AmazonECSTaskExecutionRolePolicy is attached by default, since that policy is the same for every service. It does not cover secrets: add ssm:GetParameters or secretsmanager:GetSecretValue via inline\_policy if the task definition references any. | <pre>object({<br/>    create                  = optional(bool, false)<br/>    arn                     = optional(string, "")<br/>    name                    = optional(string, "")<br/>    inline_policy           = optional(string, "")<br/>    attach_policies         = optional(list(string), [])<br/>    attach_execution_policy = optional(bool, true)<br/>  })</pre> | `{}` | no |
| <a name="input_log_anomaly_detection"></a> [log\_anomaly\_detection](#input\_log\_anomaly\_detection) | CloudWatch Logs Anomaly Detection configuration | <pre>object({<br/>    enabled                 = optional(bool, false)<br/>    evaluation_frequency    = optional(string, "TEN_MIN")<br/>    anomaly_visibility_time = optional(number, 7)<br/>    filter_pattern          = optional(string, "")<br/>  })</pre> | `{}` | no |
| <a name="input_log_kms_key_id"></a> [log\_kms\_key\_id](#input\_log\_kms\_key\_id) | ARN of a KMS key to encrypt the CloudWatch log group. Empty uses the default AWS-owned key. The key policy must allow the CloudWatch Logs service principal in this region. | `string` | `""` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Number of days to retain logs | `number` | `7` | no |
| <a name="input_network_mode"></a> [network\_mode](#input\_network\_mode) | Network mode for the ECS task definition. Fargate requires 'awsvpc'. EC2 supports 'awsvpc', 'bridge', 'host', or 'none'. | `string` | `"awsvpc"` | no |
| <a name="input_placement_constraints"></a> [placement\_constraints](#input\_placement\_constraints) | Placement constraints for ECS service (only applicable for EC2 launch type). Type can be distinctInstance or memberOf. | <pre>list(object({<br/>    type       = string<br/>    expression = optional(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_placement_strategy"></a> [placement\_strategy](#input\_placement\_strategy) | Ordered placement strategy for ECS service (only applicable for EC2 launch type). Type can be binpack, spread, or random. | <pre>list(object({<br/>    type  = string<br/>    field = optional(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_security_group_ids"></a> [security\_group\_ids](#input\_security\_group\_ids) | Security group IDs for the ECS tasks. Required when network\_mode is 'awsvpc'. | `list(string)` | `[]` | no |
| <a name="input_service_connect"></a> [service\_connect](#input\_service\_connect) | ECS Service Connect configuration. type = client-only joins the namespace as a client; client-server also advertises this service (default port plus optional additional\_ports) for discovery by other services. The namespace is assumed to share the cluster name. | <pre>object({<br/>    enabled     = optional(bool, false)<br/>    type        = optional(string, "client-only")<br/>    port        = optional(number, 80)<br/>    name        = optional(string, "service")<br/>    timeout     = optional(number, 15)<br/>    appProtocol = optional(string, "http")<br/>    additional_ports = optional(list(object({<br/>      name        = string<br/>      port        = number<br/>      appProtocol = optional(string, "http")<br/>    })), [])<br/>  })</pre> | `{}` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Subnet IDs for the ECS tasks. Required when network\_mode is 'awsvpc'. | `list(string)` | `[]` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to add to all resources | `map(string)` | `{}` | no |
| <a name="input_task_definition_template"></a> [task\_definition\_template](#input\_task\_definition\_template) | A task definition kept up to date by Terraform in its own family,<br/>"<cluster>\_<service>-template" by default, for the deploy pipeline to copy.<br/>The pipeline reads the latest revision, swaps the image of `container_name`<br/>for the build it is deploying, and registers the result into the service's<br/>family. Unlike the write-once task definition the service starts with,<br/>every change here registers a new template revision, but nothing reaches<br/>running tasks until the next deploy.<br/><br/>The container definitions are generated from the keys below, which mirror<br/>the task config YAML of delivops/ecs-deploy-action: the `container_name`<br/>container, a secret-file init container, the fluent-bit and otel-collector<br/>containers, and `sidecars`. Log configuration points at the module's log<br/>group. The image of `container_name` is `container_image`, a placeholder the<br/>pipeline replaces. The task and execution roles, network mode and launch<br/>type come from the module's own inputs.<br/><br/>- `envs`: environment variables.<br/>- `secrets`: env var name => Secrets Manager secret ARN; the variable takes<br/>  the value of the JSON key with the same name.<br/>- `secrets_envs`: [{ id = secret ARN, values = [JSON keys] }]; each key<br/>  becomes an env var of the same name. Mutually exclusive with `secrets`.<br/>- `secrets_value_from`: env var name => a `valueFrom` used verbatim (an SSM<br/>  parameter, or a whole secret).<br/>- `secret_files`: secrets downloaded to `secrets_files_path` by an init<br/>  container before the container starts.<br/>- `writable_dirs`: an empty volume mounted per path, for use with<br/>  `readonly_root_filesystem`.<br/>- `otel_collector`: set (even to {}) to add the collector. Without<br/>  `image_name`/`image` it runs the public ADOT image with its config read<br/>  from the SSM parameter `ssm_name`.<br/>- `fluent_bit_collector`: adds fluent-bit from `image_name` or `image` (one<br/>  is required) and routes the application's logs through FireLens.<br/>- `image_name` on either collector is a repository in this account's ECR<br/>  registry; `image` is a full image reference.<br/>- `volumes`: extra task volumes, alongside the generated ones.<br/>- `container_definitions`: extra containers in ECS API shape, appended as-is.<br/>- `container_overrides`: generated container name => ECS API fields merged<br/>  over it, for anything the keys above don't cover.<br/>- `replica_count`: published to SSM for the pipeline to set the service's<br/>  desired count on deploy. Leave null for autoscaled services.<br/><br/>The family name is published to SSM at<br/>/ecs/<cluster>/<service>/task-definition-template. | <pre>object({<br/>    enabled                 = optional(bool, false)<br/>    family_suffix           = optional(string, "-template")<br/>    cpu                     = optional(number)<br/>    memory                  = optional(number)<br/>    cpu_architecture        = optional(string, "X86_64")<br/>    operating_system_family = optional(string, "LINUX")<br/>    ephemeral_storage_gib   = optional(number)<br/>    replica_count           = optional(number)<br/><br/>    port                     = optional(number)<br/>    additional_ports         = optional(map(number), {})<br/>    app_protocol             = optional(string, "http")<br/>    command                  = optional(list(string), [])<br/>    entrypoint               = optional(list(string), [])<br/>    stop_timeout             = optional(number)<br/>    envs                     = optional(map(string), {})<br/>    secrets                  = optional(map(string), {})<br/>    secrets_envs             = optional(list(object({ id = string, values = list(string) })), [])<br/>    secrets_value_from       = optional(map(string), {})<br/>    secret_files             = optional(list(string), [])<br/>    secrets_files_path       = optional(string, "/etc/secrets")<br/>    readonly_root_filesystem = optional(bool)<br/>    writable_dirs            = optional(list(string), [])<br/>    health_check = optional(object({<br/>      command      = optional(string)<br/>      interval     = optional(number, 30)<br/>      timeout      = optional(number, 5)<br/>      retries      = optional(number, 3)<br/>      start_period = optional(number, 10)<br/>    }))<br/>    linux_parameters = optional(object({<br/>      init_process_enabled = optional(bool)<br/>      capabilities = optional(object({<br/>        add  = optional(list(string), [])<br/>        drop = optional(list(string), [])<br/>      }))<br/>      tmpfs = optional(list(object({<br/>        container_path = optional(string, "/tmp")<br/>        size           = optional(number, 64)<br/>        mount_options  = optional(list(string), [])<br/>      })), [])<br/>      swappiness         = optional(number)<br/>      max_swap           = optional(number)<br/>      shared_memory_size = optional(number)<br/>      devices = optional(list(object({<br/>        host_path      = string<br/>        container_path = optional(string)<br/>        permissions    = optional(list(string), ["read", "write"])<br/>      })), [])<br/>    }))<br/><br/>    otel_collector = optional(object({<br/>      image_name   = optional(string, "")<br/>      image        = optional(string)<br/>      ssm_name     = optional(string, "adot-config-global.yaml")<br/>      extra_config = optional(string, "")<br/>      metrics_port = optional(number, 8080)<br/>      metrics_path = optional(string, "/metrics")<br/>    }))<br/>    fluent_bit_collector = optional(object({<br/>      image_name       = optional(string, "")<br/>      image            = optional(string)<br/>      extra_config     = optional(string, "extra.conf")<br/>      ecs_log_metadata = optional(bool, true)<br/>      service_name     = optional(string)<br/>    }))<br/><br/>    sidecars = optional(list(object({<br/>      name                     = string<br/>      image                    = string<br/>      enabled                  = optional(bool, true)<br/>      essential                = optional(bool, true)<br/>      port                     = optional(number)<br/>      additional_ports         = optional(map(number), {})<br/>      app_protocol             = optional(string, "http")<br/>      command                  = optional(list(string), [])<br/>      entrypoint               = optional(list(string), [])<br/>      stop_timeout             = optional(number)<br/>      envs                     = optional(map(string), {})<br/>      secrets                  = optional(map(string), {})<br/>      secrets_envs             = optional(list(object({ id = string, values = list(string) })), [])<br/>      secrets_value_from       = optional(map(string), {})<br/>      secret_files             = optional(list(string), [])<br/>      secrets_files_path       = optional(string, "/etc/secrets")<br/>      readonly_root_filesystem = optional(bool)<br/>      writable_dirs            = optional(list(string), [])<br/>      cpu                      = optional(number)<br/>      memory                   = optional(number)<br/>      memory_reservation       = optional(number)<br/>      log_stream_prefix        = optional(string)<br/>      health_check = optional(object({<br/>        command      = optional(string)<br/>        interval     = optional(number, 30)<br/>        timeout      = optional(number, 5)<br/>        retries      = optional(number, 3)<br/>        start_period = optional(number, 10)<br/>      }))<br/>      linux_parameters = optional(object({<br/>        init_process_enabled = optional(bool)<br/>        capabilities = optional(object({<br/>          add  = optional(list(string), [])<br/>          drop = optional(list(string), [])<br/>        }))<br/>        tmpfs = optional(list(object({<br/>          container_path = optional(string, "/tmp")<br/>          size           = optional(number, 64)<br/>          mount_options  = optional(list(string), [])<br/>        })), [])<br/>        swappiness         = optional(number)<br/>        max_swap           = optional(number)<br/>        shared_memory_size = optional(number)<br/>        devices = optional(list(object({<br/>          host_path      = string<br/>          container_path = optional(string)<br/>          permissions    = optional(list(string), ["read", "write"])<br/>        })), [])<br/>      }))<br/>    })), [])<br/><br/>    volumes = optional(list(object({<br/>      name      = string<br/>      host_path = optional(string)<br/>      efs_volume_configuration = optional(object({<br/>        file_system_id          = string<br/>        root_directory          = optional(string)<br/>        transit_encryption      = optional(string)<br/>        transit_encryption_port = optional(number)<br/>        authorization_config = optional(object({<br/>          access_point_id = optional(string)<br/>          iam             = optional(string)<br/>        }))<br/>      }))<br/>    })), [])<br/>    container_definitions = optional(any, [])<br/>    container_overrides   = optional(any, {})<br/>  })</pre> | `{}` | no |
| <a name="input_task_role"></a> [task\_role](#input\_task\_role) | IAM role the container assumes — the application's own permissions. Either create it here (create = true, with inline\_policy and attach\_policies) or supply an existing one (arn). It starts with no permissions: only the application knows what it needs. That includes ECS Exec — enable\_execute\_command needs ssmmessages:CreateControlChannel, CreateDataChannel, OpenControlChannel and OpenDataChannel added via inline\_policy. | <pre>object({<br/>    create          = optional(bool, false)<br/>    arn             = optional(string, "")<br/>    name            = optional(string, "")<br/>    inline_policy   = optional(string, "")<br/>    attach_policies = optional(list(string), [])<br/>  })</pre> | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of the VPC | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cloudwatch_log_group_name"></a> [cloudwatch\_log\_group\_name](#output\_cloudwatch\_log\_group\_name) | n/a |
| <a name="output_ecs_service_name"></a> [ecs\_service\_name](#output\_ecs\_service\_name) | n/a |
| <a name="output_ecs_task_definition_arn"></a> [ecs\_task\_definition\_arn](#output\_ecs\_task\_definition\_arn) | n/a |
| <a name="output_execution_role_arn"></a> [execution\_role\_arn](#output\_execution\_role\_arn) | ARN of the execution role in effect, whether created here or supplied (null when there is none). |
| <a name="output_execution_role_name"></a> [execution\_role\_name](#output\_execution\_role\_name) | Name of the execution role created by this module (null unless execution\_role.create = true). |
| <a name="output_load_balancer"></a> [load\_balancer](#output\_load\_balancer) | DNS details of the ALB(s) fronting the service. Use these (e.g. dns\_name) to create DNS records such as Cloudflare CNAMEs outside this module. |
| <a name="output_log_anomaly_detector_arn"></a> [log\_anomaly\_detector\_arn](#output\_log\_anomaly\_detector\_arn) | ARN of the CloudWatch Logs Anomaly Detector (if enabled) |
| <a name="output_log_anomaly_detector_name"></a> [log\_anomaly\_detector\_name](#output\_log\_anomaly\_detector\_name) | Name of the CloudWatch Logs Anomaly Detector (if enabled) |
| <a name="output_route53_records"></a> [route53\_records](#output\_route53\_records) | Route53 DNS records created |
| <a name="output_ssm_execution_role_parameter_name"></a> [ssm\_execution\_role\_parameter\_name](#output\_ssm\_execution\_role\_parameter\_name) | Name of the SSM parameter holding the execution role ARN (null when no execution role exists). |
| <a name="output_ssm_replica_count_parameter_name"></a> [ssm\_replica\_count\_parameter\_name](#output\_ssm\_replica\_count\_parameter\_name) | Name of the SSM parameter holding the desired count for the deploy pipeline (null unless task\_definition\_template.enabled and replica\_count is set). |
| <a name="output_ssm_task_definition_template_parameter_name"></a> [ssm\_task\_definition\_template\_parameter\_name](#output\_ssm\_task\_definition\_template\_parameter\_name) | Name of the SSM parameter holding the task definition template family (null unless task\_definition\_template.enabled). |
| <a name="output_ssm_task_role_parameter_name"></a> [ssm\_task\_role\_parameter\_name](#output\_ssm\_task\_role\_parameter\_name) | Name of the SSM parameter holding the task role ARN (null when no task role exists). |
| <a name="output_task_definition_template_arn"></a> [task\_definition\_template\_arn](#output\_task\_definition\_template\_arn) | ARN of the latest task definition template revision (null unless task\_definition\_template.enabled). |
| <a name="output_task_definition_template_family"></a> [task\_definition\_template\_family](#output\_task\_definition\_template\_family) | Family of the Terraform-managed task definition template (null unless task\_definition\_template.enabled). |
| <a name="output_task_role_arn"></a> [task\_role\_arn](#output\_task\_role\_arn) | ARN of the task role in effect, whether created here or supplied (null when there is none). |
| <a name="output_task_role_name"></a> [task\_role\_name](#output\_task\_role\_name) | Name of the task role created by this module (null unless task\_role.create = true). |
<!-- END_TF_DOCS -->
