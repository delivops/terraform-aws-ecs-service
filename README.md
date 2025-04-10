![image info](logo.jpeg)

# AWS ECS Service Terraform Module

This Terraform module deploys an ECS service on AWS Fargate with support for load balancing, auto-scaling, and custom deployment configurations.

## Features

- Creates an ECS service with Fargate launch type
- Configurable load balancer target group with health checks
- Support for host-based and path-based routing rules
- Auto-scaling capabilities based on CPU and Memory utilization
- CloudWatch logging integration
- Deployment circuit breaker and CloudWatch alarms integration
- ARM64 architecture support

## Resources Created

- ECS Service with Fargate launch type
- ECS Task Definition
- Application/Network Load Balancer Target Group (optional)
- Load Balancer Listener Rules (host-based and path-based)
- CloudWatch Log Group
- Auto Scaling Target and Policies
- CloudWatch Alarms (optional)

## Usage

```python

################################################################################
# AWS ECS-SERVICE (without ALB)
################################################################################

module "demo_ecs_service" {
  source  = "delivops/ecs-service/aws"
  version = "xxx"

  ecs_cluster_name   = var.cluster_name
  ecs_service_name   = "demo"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

}
```

```python

################################################################################
# AWS ECS-SERVICE (with ALB)
################################################################################

module "alb_ecs_service" {
  source  = "delivops/ecs-service/aws"
  version = "xxx"
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

## Notes

- The module uses ARM64 architecture by default
- The task definition is configured with 1024 CPU units and 2048MB memory
- Default container image is nginx:stable
- The module ignores changes to task definition and container definitions to support external deployments
- If you work with load balancer from type NLB, you should create it yourself (not with terraform), and also to put the target_group_protocol and health_check_protocol to "TCP".

## License

This module is released under the MIT License.

<!-- BEGIN_TF_DOCS -->

## Requirements

No requirements.

## Providers

| Name                                                            | Version |
| --------------------------------------------------------------- | ------- |
| <a name="provider_aws"></a> [aws](#provider_aws)                | 5.94.1  |
| <a name="provider_external"></a> [external](#provider_external) | 2.3.4   |

## Modules

No modules.

## Resources

| Name                                                                                                                                                              | Type        |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| [aws_alb_target_group.target_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/alb_target_group)                                 | resource    |
| [aws_appautoscaling_policy.scale_by_cpu_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy)                | resource    |
| [aws_appautoscaling_policy.scale_by_memory_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy)             | resource    |
| [aws_appautoscaling_policy.scale_in_by_sqs_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy)             | resource    |
| [aws_appautoscaling_policy.scale_out_by_sqs_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy)            | resource    |
| [aws_appautoscaling_target.ecs_target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_target)                         | resource    |
| [aws_cloudwatch_log_group.ecs_log_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group)                        | resource    |
| [aws_cloudwatch_metric_alarm.in_sqs_auto_scaling](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm)            | resource    |
| [aws_cloudwatch_metric_alarm.out_sqs_auto_scaling](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm)           | resource    |
| [aws_ecs_service.ecs_service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service)                                            | resource    |
| [aws_ecs_task_definition.task_definition](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition)                        | resource    |
| [aws_lb_listener_rule.rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule)                                         | resource    |
| [aws_ecs_cluster.ecs_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ecs_cluster)                                         | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region)                                                       | data source |
| [aws_service_discovery_http_namespace.namespace](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/service_discovery_http_namespace) | data source |
| [external_external.listener_rules](https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external)                                  | data source |

## Inputs

| Name                                                                                                                                          | Description                               | Type                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | Default          | Required |
| --------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------- | :------: |
| <a name="input_application_load_balancer"></a> [application_load_balancer](#input_application_load_balancer)                                  | alb                                       | <pre>object({<br/> enabled = optional(bool, false)<br/> container_port = optional(number, 80)<br/> listener_arn = optional(string, "")<br/> host = optional(string, "")<br/> path = optional(string, "/\*")<br/> protocol = optional(string, "HTTP")<br/> health_check_path = optional(string, "/health")<br/> health_check_matcher = optional(string, "200")<br/> health_check_interval_sec = optional(number, 30)<br/> health_check_timeout_sec = optional(number, 5)<br/> health_check_threshold_healthy = optional(number, 3)<br/> health_check_threshold_unhealthy = optional(number, 3)<br/> health_check_protocol = optional(string, "HTTP")<br/><br/> })</pre> | `{}`             |    no    |
| <a name="input_assign_public_ip"></a> [assign_public_ip](#input_assign_public_ip)                                                             | Assign public IP to ECS tasks             | `bool`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 | `false`          |    no    |
| <a name="input_container_image"></a> [container_image](#input_container_image)                                                                | Docker image for the container            | `string`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               | `"nginx:latest"` |    no    |
| <a name="input_container_name"></a> [container_name](#input_container_name)                                                                   | Name of the container                     | `string`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               | `"app"`          |    no    |
| <a name="input_cpu_auto_scaling"></a> [cpu_auto_scaling](#input_cpu_auto_scaling)                                                             | value for auto scaling                    | <pre>object({<br/> enabled = optional(bool, false)<br/> min_replicas = optional(number, 1)<br/> max_replicas = optional(number, 1)<br/> scale_in_cooldown = optional(number, 300)<br/> scale_out_cooldown = optional(number, 300)<br/> target_value = optional(number, 70)<br/> })</pre>                                                                                                                                                                                                                                                                                                                                                                               | `{}`             |    no    |
| <a name="input_deployment_circuit_breaker"></a> [deployment_circuit_breaker](#input_deployment_circuit_breaker)                               | Enable deployment circuit breaker         | `bool`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 | `true`           |    no    |
| <a name="input_deployment_cloudwatch_alarm_enabled"></a> [deployment_cloudwatch_alarm_enabled](#input_deployment_cloudwatch_alarm_enabled)    | Enable CloudWatch alarms for deployment   | `bool`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 | `false`          |    no    |
| <a name="input_deployment_cloudwatch_alarm_names"></a> [deployment_cloudwatch_alarm_names](#input_deployment_cloudwatch_alarm_names)          | Names of CloudWatch alarms for deployment | `list(string)`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         | `[]`             |    no    |
| <a name="input_deployment_cloudwatch_alarm_rollback"></a> [deployment_cloudwatch_alarm_rollback](#input_deployment_cloudwatch_alarm_rollback) | Enable rollback on CloudWatch alarm       | `bool`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 | `true`           |    no    |
| <a name="input_deployment_max_percent"></a> [deployment_max_percent](#input_deployment_max_percent)                                           | Maximum percent during deployment         | `number`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               | `200`            |    no    |
| <a name="input_deployment_min_healthy"></a> [deployment_min_healthy](#input_deployment_min_healthy)                                           | Minimum healthy percent during deployment | `number`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               | `100`            |    no    |
| <a name="input_deployment_rollback"></a> [deployment_rollback](#input_deployment_rollback)                                                    | Enable deployment rollback                | `bool`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 | `true`           |    no    |
| <a name="input_ecs_cluster_name"></a> [ecs_cluster_name](#input_ecs_cluster_name)                                                             | Name of the ECS cluster                   | `string`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               | n/a              |   yes    |
| <a name="input_desired_count"></a> [ecs_desired_count](#input_ecs_desired_count)                                                              | Desired number of tasks                   | `number`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               | `1`              |    no    |
| <a name="input_ecs_launch_type"></a> [ecs_launch_type](#input_ecs_launch_type)                                                                | Launch type for the ECS service           | `string`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               | `"FARGATE"`      |    no    |
| <a name="input_ecs_service_name"></a> [ecs_service_name](#input_ecs_service_name)                                                             | Name of the ECS service                   | `string`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               | n/a              |   yes    |
| <a name="input_ecs_task_cpu"></a> [ecs_task_cpu](#input_ecs_task_cpu)                                                                         | CPU units for the ECS task                | `number`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               | `256`            |    no    |
| <a name="input_ecs_task_memory"></a> [ecs_task_memory](#input_ecs_task_memory)                                                                | Memory for the ECS task in MiB            | `number`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               | `512`            |    no    |
| <a name="input_log_retention_days"></a> [log_retention_days](#input_log_retention_days)                                                       | Number of days to retain logs             | `number`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               | `7`              |    no    |
| <a name="input_memory_auto_scaling"></a> [memory_auto_scaling](#input_memory_auto_scaling)                                                    | value for auto scaling                    | <pre>object({<br/> enabled = optional(bool, false)<br/> min_replicas = optional(number, 1)<br/> max_replicas = optional(number, 1)<br/> scale_in_cooldown = optional(number, 300)<br/> scale_out_cooldown = optional(number, 300)<br/> target_value = optional(number, 70)<br/><br/> })</pre>                                                                                                                                                                                                                                                                                                                                                                          | `{}`             |    no    |
| <a name="input_security_group_ids"></a> [security_group_ids](#input_security_group_ids)                                                       | Security group IDs for the ECS tasks      | `list(string)`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         | n/a              |   yes    |
| <a name="input_service_connect"></a> [service_connect](#input_service_connect)                                                                | n/a                                       | <pre>object({<br/> enabled = optional(bool, false)<br/> type = optional(string, "client-only")<br/> port = optional(number, 80)<br/> additional_ports = optional(list(object({<br/> name = string<br/> port = number<br/> })), [])<br/> })</pre>                                                                                                                                                                                                                                                                                                                                                                                                                       | `{}`             |    no    |
| <a name="input_sqs_auto_scaling"></a> [sqs_auto_scaling](#input_sqs_auto_scaling)                                                             | value for auto scaling                    | <pre>object({<br/> enabled = optional(bool, false)<br/> min_replicas = optional(number, 1)<br/> max_replicas = optional(number, 1)<br/> queue_name = optional(string, "")<br/> scale_in_step = optional(number, 1)<br/> scale_out_step = optional(number, 1)<br/> scale_in_cooldown = optional(number, 300)<br/> scale_out_cooldown = optional(number, 300)<br/> scale_in_threshold = optional(number, 10)<br/> scale_out_threshold = optional(number, 100)<br/> })</pre>                                                                                                                                                                                              | `{}`             |    no    |
| <a name="input_subnet_ids"></a> [subnet_ids](#input_subnet_ids)                                                                               | Subnet IDs for the ECS tasks              | `list(string)`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         | n/a              |   yes    |
| <a name="input_vpc_id"></a> [vpc_id](#input_vpc_id)                                                                                           | ID of the VPC                             | `string`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               | n/a              |   yes    |

## Outputs

| Name                                                                                                           | Description |
| -------------------------------------------------------------------------------------------------------------- | ----------- |
| <a name="output_cloudwatch_log_group_name"></a> [cloudwatch_log_group_name](#output_cloudwatch_log_group_name) | n/a         |
| <a name="output_ecs_service_name"></a> [ecs_service_name](#output_ecs_service_name)                            | n/a         |
| <a name="output_ecs_task_definition_arn"></a> [ecs_task_definition_arn](#output_ecs_task_definition_arn)       | n/a         |

<!-- END_TF_DOCS -->
