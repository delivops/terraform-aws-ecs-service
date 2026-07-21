[![DelivOps banner](https://raw.githubusercontent.com/delivops/.github/main/images/banner.png?raw=true)](https://delivops.com)

# AWS ECS Service Terraform Module

This Terraform module deploys an ECS service (Fargate or EC2) with support for load balancing and custom deployment configurations.

> **Autoscaling is not managed by this module.** Attach your own
> `aws_appautoscaling_target`/`aws_appautoscaling_policy` resources to the
> service using the `ecs_service_name` output.

## Features

- Creates an ECS service with Fargate or EC2 launch type
- Configurable load balancer target group with health checks
- Support for host-based and path-based routing rules
- CloudWatch logging integration (optional KMS encryption)
- Deployment circuit breaker and CloudWatch alarms integration
- Route53 DNS record management (other providers, e.g. Cloudflare, can be wired via the `load_balancer` output)

## Resources Created

- ECS Service (Fargate or EC2 launch type)
- ECS Task Definition
- Application/Network Load Balancer Target Group (optional)
- Load Balancer Listener Rules (host-based and path-based)
- CloudWatch Log Group
- ECR Repository (optional)
- Route53 DNS Records (optional)

## Usage

```hcl

################################################################################
# AWS ECS-SERVICE (without ALB)
################################################################################

module "demo_ecs_service" {
  source  = "delivops/ecs-service/aws"
  version = "~> 1.0" # pin to a released version; see the repo Releases

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
  version = "~> 1.0" # pin to a released version; see the repo Releases
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
  version = "~> 1.0" # pin to a released version; see the repo Releases
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
  version = "~> 1.0" # pin to a released version; see the repo Releases
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

## Service IAM Role

By default the module creates no IAM. You can either pass an existing role via
`initial_role`, or let the module create a dedicated role for the service via the
`role` block. When `role.create = true`, the created role is assumable only by the
ECS tasks service (`ecs-tasks.amazonaws.com`) and its ARN becomes the default for
**both** `task_role_arn` and `execution_role_arn` — so `initial_role` is no longer
needed (if set, it is ignored while `role.create = true`).

```hcl
module "ecs_service" {
  source           = "delivops/ecs-service/aws"
  ecs_cluster_name = "production"
  ecs_service_name = "worker"
  # ... networking ...

  role = {
    create                  = true
    attach_execution_policy = true # attach AmazonECSTaskExecutionRolePolicy
    inline_policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect   = "Allow"
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage"]
        Resource = "*"
      }]
    })
    attach_policies = ["arn:aws:iam::aws:policy/AmazonSQSReadOnlyAccess"]
  }
}
```

| Field | Type | Default | Description |
|---|---|---|---|
| `create` | `bool` | `false` | Create the role. Off by default. |
| `name` | `string` | `""` | Role name. Defaults to `"<cluster>_<service>"`. |
| `inline_policy` | `string` | `""` | Inline IAM policy document (JSON). |
| `attach_policies` | `list(string)` | `[]` | Managed policy ARNs to attach. |
| `attach_execution_policy` | `bool` | `false` | Attach `AmazonECSTaskExecutionRolePolicy`. |

The created role's ARN and name are available via the `service_role_arn` and
`service_role_name` outputs. The legacy `initial_role` input continues to work
for callers that manage the role themselves.

## SSM Parameters

The module publishes per-service metadata to SSM Parameter Store so a deploy
pipeline can read it without reconstructing values:

| Parameter | Value | Notes |
|---|---|---|
| `/ecs/<cluster>/<service>/role` | Effective task/execution role ARN | Not created when no role exists (`role.create = false` and `initial_role` empty). |

The parameter name is exposed via the `ssm_role_parameter_name` output.

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

## Notes

- Task CPU and memory default to 256 units / 512 MiB and are configurable via `ecs_task_cpu` and `ecs_task_memory`
- The default container image is `nginx:latest` (override with `container_image`)
- The module ignores changes to the task definition to support external (CI-managed) deployments
- If you work with load balancer from type NLB, you should create it yourself (not with terraform), and also to put the target_group_protocol and health_check_protocol to "TCP".

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
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.inline](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.attached](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lb_listener.tcp_listener](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener.tcp_listener_additional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener_rule.rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule) | resource |
| [aws_lb_listener_rule.rule_additional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule) | resource |
| [aws_route53_record.additional_alb_records](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.main_alb_record](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_ssm_parameter.role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
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
| <a name="input_application_load_balancer"></a> [application\_load\_balancer](#input\_application\_load\_balancer) | Primary load balancer configuration for the service: target group, health checks, listener rule (host/path routing or fixed-response), stickiness, and optional Route53 record. Set enabled = true to attach the service to an existing ALB/NLB listener. | <pre>object({<br/>    enabled                          = optional(bool, false)<br/>    container_port                   = optional(number, 80)<br/>    listener_arn                     = optional(string, "")<br/>    nlb_arn                          = optional(string, "")<br/>    nlb_port                         = optional(number, 80)<br/>    host                             = optional(string, "")<br/>    path                             = optional(string, "/*")<br/>    protocol                         = optional(string, "HTTP")<br/>    health_check_path                = optional(string, "/health")<br/>    health_check_matcher             = optional(string, "200")<br/>    health_check_interval_sec        = optional(number, 30)<br/>    health_check_timeout_sec         = optional(number, 10)<br/>    health_check_threshold_healthy   = optional(number, 2)<br/>    health_check_threshold_unhealthy = optional(number, 5)<br/>    health_check_protocol            = optional(string, "HTTP")<br/>    health_check_port                = optional(string, "traffic-port")<br/>    stickiness                       = optional(bool, false)<br/>    stickiness_ttl                   = optional(number, 300)<br/>    cookie_name                      = optional(string, "")<br/>    stickiness_type                  = optional(string, "app_cookie")<br/>    action_type                      = optional(string, "forward")<br/>    target_group_name                = optional(string, "")<br/>    deregister_deregistration_delay  = optional(number, 60)<br/>    route_53_host_zone_id            = optional(string, "")<br/>  })</pre> | `{}` | no |
| <a name="input_assign_public_ip"></a> [assign\_public\_ip](#input\_assign\_public\_ip) | Assign public IP to ECS tasks | `bool` | `false` | no |
| <a name="input_capacity_provider_strategy"></a> [capacity\_provider\_strategy](#input\_capacity\_provider\_strategy) | Name of an existing ECS capacity provider to use for the service. When set, the service uses this capacity provider instead of a plain launch\_type (EC2/Fargate). Leave empty to use var.ecs\_launch\_type directly. | `string` | `""` | no |
| <a name="input_container_image"></a> [container\_image](#input\_container\_image) | Docker image for the container | `string` | `"nginx:latest"` | no |
| <a name="input_container_name"></a> [container\_name](#input\_container\_name) | Name of the container | `string` | `"app"` | no |
| <a name="input_deployment"></a> [deployment](#input\_deployment) | Deployment configuration for the ECS service | <pre>object({<br/>    min_healthy_percent       = optional(number, 100)<br/>    max_healthy_percent       = optional(number, 200)<br/>    circuit_breaker_enabled   = optional(bool, true)<br/>    rollback_enabled          = optional(bool, true)<br/>    cloudwatch_alarm_enabled  = optional(bool, false)<br/>    cloudwatch_alarm_rollback = optional(bool, true)<br/>    cloudwatch_alarm_names    = optional(list(string), [])<br/>  })</pre> | `{}` | no |
| <a name="input_desired_count"></a> [desired\_count](#input\_desired\_count) | Desired number of tasks | `number` | `1` | no |
| <a name="input_ecr"></a> [ecr](#input\_ecr) | ECR repository configuration | <pre>object({<br/>    create_repo         = optional(bool, false)<br/>    repo_name           = optional(string, "")<br/>    mutability          = optional(string, "IMMUTABLE")<br/>    scan_on_push        = optional(bool, true)<br/>    kms_key_id          = optional(string, "") # KMS key ARN for repo encryption. Empty = AES256.<br/>    untagged_ttl_days   = optional(number, 7)<br/>    tagged_ttl_days     = optional(number, 7)<br/>    protected_prefixes  = optional(list(string), ["main", "master"])<br/>    protected_retention = optional(number, 999999) # Keep nearly forever<br/>    versioned_prefixes  = optional(list(string), ["v", "sha"])<br/>    versioned_retention = optional(number, 30) # How many versioned tags to keep<br/>  })</pre> | `{}` | no |
| <a name="input_ecs_cluster_name"></a> [ecs\_cluster\_name](#input\_ecs\_cluster\_name) | Name of the ECS cluster | `string` | n/a | yes |
| <a name="input_ecs_launch_type"></a> [ecs\_launch\_type](#input\_ecs\_launch\_type) | Launch type for the ECS service (FARGATE or EC2) | `string` | `"FARGATE"` | no |
| <a name="input_ecs_service_name"></a> [ecs\_service\_name](#input\_ecs\_service\_name) | Name of the ECS service | `string` | n/a | yes |
| <a name="input_ecs_task_cpu"></a> [ecs\_task\_cpu](#input\_ecs\_task\_cpu) | CPU units for the ECS task | `number` | `256` | no |
| <a name="input_ecs_task_memory"></a> [ecs\_task\_memory](#input\_ecs\_task\_memory) | Memory for the ECS task in MiB | `number` | `512` | no |
| <a name="input_enable_execute_command"></a> [enable\_execute\_command](#input\_enable\_execute\_command) | Enable execute command | `bool` | `false` | no |
| <a name="input_execution_role_arn"></a> [execution\_role\_arn](#input\_execution\_role\_arn) | ARN of the IAM role for the ECS agent (execution role: ECR pull, log write, secret fetch). Overrides the shared/default role. Leave empty to fall back to the module-created role (role.create) or initial\_role. | `string` | `""` | no |
| <a name="input_gpu_count"></a> [gpu\_count](#input\_gpu\_count) | Number of GPUs to request for the container (EC2 launch type only). 0 disables GPU resource requirements. | `number` | `0` | no |
| <a name="input_initial_role"></a> [initial\_role](#input\_initial\_role) | ARN of an existing IAM role to use for both task role and execution role. Must be a full IAM role ARN (task\_role\_arn/execution\_role\_arn require ARNs, not names). Ignored when role.create = true, in which case the module-created role is used instead. | `string` | `""` | no |
| <a name="input_log_anomaly_detection"></a> [log\_anomaly\_detection](#input\_log\_anomaly\_detection) | CloudWatch Logs Anomaly Detection configuration | <pre>object({<br/>    enabled                 = optional(bool, false)<br/>    evaluation_frequency    = optional(string, "TEN_MIN")<br/>    anomaly_visibility_time = optional(number, 7)<br/>    filter_pattern          = optional(string, "")<br/>  })</pre> | `{}` | no |
| <a name="input_log_kms_key_id"></a> [log\_kms\_key\_id](#input\_log\_kms\_key\_id) | ARN of a KMS key to encrypt the CloudWatch log group. Leave empty to use the default AWS-owned key. | `string` | `""` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Number of days to retain logs | `number` | `7` | no |
| <a name="input_network_mode"></a> [network\_mode](#input\_network\_mode) | Network mode for the ECS task definition. Fargate requires 'awsvpc'. EC2 supports 'awsvpc', 'bridge', 'host', or 'none'. | `string` | `"awsvpc"` | no |
| <a name="input_placement_constraints"></a> [placement\_constraints](#input\_placement\_constraints) | Placement constraints for ECS service (only applicable for EC2 launch type). Type can be distinctInstance or memberOf. | <pre>list(object({<br/>    type       = string<br/>    expression = optional(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_placement_strategy"></a> [placement\_strategy](#input\_placement\_strategy) | Ordered placement strategy for ECS service (only applicable for EC2 launch type). Type can be binpack, spread, or random. | <pre>list(object({<br/>    type  = string<br/>    field = optional(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_role"></a> [role](#input\_role) | Optionally create a dedicated IAM role for this service, assumable only by the ECS tasks service (ecs-tasks.amazonaws.com). When create = true, the role's ARN becomes the default for both task\_role\_arn and execution\_role\_arn, so initial\_role need not be set. | <pre>object({<br/>    create                  = optional(bool, false)      # Create the role. Default off.<br/>    name                    = optional(string, "")       # Role name. Defaults to "<cluster>_<service>".<br/>    inline_policy           = optional(string, "")       # Inline IAM policy document (JSON, e.g. jsonencode({...})).<br/>    attach_policies         = optional(list(string), []) # Managed policy ARNs to attach.<br/>    attach_execution_policy = optional(bool, false)      # Attach AmazonECSTaskExecutionRolePolicy.<br/>  })</pre> | `{}` | no |
| <a name="input_security_group_ids"></a> [security\_group\_ids](#input\_security\_group\_ids) | Security group IDs for the ECS tasks. Required when network\_mode is 'awsvpc'. | `list(string)` | `[]` | no |
| <a name="input_service_connect"></a> [service\_connect](#input\_service\_connect) | ECS Service Connect configuration. type = client-only joins the namespace as a client; client-server also advertises this service (default port plus optional additional\_ports) for discovery by other services. | <pre>object({<br/>    enabled     = optional(bool, false)<br/>    type        = optional(string, "client-only")<br/>    port        = optional(number, 80)<br/>    name        = optional(string, "service")<br/>    timeout     = optional(number, 15)<br/>    appProtocol = optional(string, "http")<br/>    additional_ports = optional(list(object({<br/>      name        = string<br/>      port        = number<br/>      appProtocol = optional(string, "http")<br/>    })), [])<br/>  })</pre> | `{}` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Subnet IDs for the ECS tasks. Required when network\_mode is 'awsvpc'. | `list(string)` | `[]` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to add to all resources | `map(string)` | `{}` | no |
| <a name="input_task_role_arn"></a> [task\_role\_arn](#input\_task\_role\_arn) | ARN of the IAM role for the task (application permissions). Overrides the shared/default role. Leave empty to fall back to the module-created role (role.create) or initial\_role. | `string` | `""` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of the VPC | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cloudwatch_log_group_name"></a> [cloudwatch\_log\_group\_name](#output\_cloudwatch\_log\_group\_name) | Name of the CloudWatch log group created for the service. |
| <a name="output_ecs_service_name"></a> [ecs\_service\_name](#output\_ecs\_service\_name) | Name of the ECS service. Use this to attach external resources (e.g. autoscaling) to the service. |
| <a name="output_ecs_task_definition_arn"></a> [ecs\_task\_definition\_arn](#output\_ecs\_task\_definition\_arn) | ARN of the initial task definition created by the module (the running task definition may be managed by a CI pipeline). |
| <a name="output_load_balancer"></a> [load\_balancer](#output\_load\_balancer) | DNS details of the ALB(s) fronting the service. Use these (e.g. dns\_name) to create DNS records such as Cloudflare CNAMEs outside this module. |
| <a name="output_log_anomaly_detector_arn"></a> [log\_anomaly\_detector\_arn](#output\_log\_anomaly\_detector\_arn) | ARN of the CloudWatch Logs Anomaly Detector (if enabled) |
| <a name="output_log_anomaly_detector_name"></a> [log\_anomaly\_detector\_name](#output\_log\_anomaly\_detector\_name) | Name of the CloudWatch Logs Anomaly Detector (if enabled) |
| <a name="output_route53_records"></a> [route53\_records](#output\_route53\_records) | Route53 DNS records created |
| <a name="output_service_role_arn"></a> [service\_role\_arn](#output\_service\_role\_arn) | ARN of the IAM role created for this service (null if role.create = false). |
| <a name="output_service_role_name"></a> [service\_role\_name](#output\_service\_role\_name) | Name of the IAM role created for this service (null if role.create = false). |
| <a name="output_ssm_role_parameter_name"></a> [ssm\_role\_parameter\_name](#output\_ssm\_role\_parameter\_name) | Name of the SSM parameter holding the service role ARN (null when no role exists). |
<!-- END_TF_DOCS -->
