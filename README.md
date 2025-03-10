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
# AWS ECS-SERVICE
################################################################################

module "ecs_service" {
  source = "delivops/ecs-service/aws"
  #version            = "0.0.1"

  cluster_name        = "my-ecs-cluster"
  service_name        = "my-service"
  vpc_id              = "vpc-xxxxxx"
  subnets             = ["subnet-xxxxx", "subnet-yyyyy"]
  security_groups     = ["sg-xxxxxx"]
  execution_role_arn  = "arn:aws:iam::xxxxxxxxxxxx:role/ecsTaskExecutionRole"

  # Load Balancer Configuration
  enable_target_group = true
  target_group_name   = "my-target-group"
  listener_arn        = "arn:aws:elasticloadbalancing:xxxxx"
  host_rules = [
  { value = "example.com", priority = 100 },
  { value = "app.example.com", priority = 200 },
  { value = "api.example.com", priority = 300 }
  ]
  # Auto Scaling Configuration
  scaling_enabled     = true
  min_capacity        = 1
  max_capacity        = 5
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

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_alb_target_group.target_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/alb_target_group) | resource |
| [aws_appautoscaling_policy.scale_by_cpu_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy) | resource |
| [aws_appautoscaling_policy.scale_by_memory_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy) | resource |
| [aws_appautoscaling_policy.scale_in_by_alarm_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy) | resource |
| [aws_appautoscaling_policy.scale_out_by_alarm_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy) | resource |
| [aws_appautoscaling_target.ecs_target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_target) | resource |
| [aws_cloudwatch_log_group.ecs_log_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_metric_alarm.in_auto_scaling](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.out_auto_scaling](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_ecs_service.ecs_service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.task_definition](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_lb_listener_rule.host_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule) | resource |
| [aws_lb_listener_rule.path_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule) | resource |
| [aws_ecs_cluster.ecs_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ecs_cluster) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_assign_public_ip"></a> [assign\_public\_ip](#input\_assign\_public\_ip) | Enable public IP assignment for ECS tasks. | `bool` | `false` | no |
| <a name="input_container_image"></a> [container\_image](#input\_container\_image) | Docker image for the ECS task. | `string` | `"nginx:stable"` | no |
| <a name="input_container_name"></a> [container\_name](#input\_container\_name) | Name of the container running in the ECS task. | `string` | `"app"` | no |
| <a name="input_container_port"></a> [container\_port](#input\_container\_port) | Port exposed by the container. | `number` | `80` | no |
| <a name="input_deployment_circuit_breaker"></a> [deployment\_circuit\_breaker](#input\_deployment\_circuit\_breaker) | Enable deployment circuit breaker. | `bool` | `false` | no |
| <a name="input_deployment_cloudwatch_alarm_enabled"></a> [deployment\_cloudwatch\_alarm\_enabled](#input\_deployment\_cloudwatch\_alarm\_enabled) | Enable CloudWatch alarm for deployment. | `bool` | `false` | no |
| <a name="input_deployment_cloudwatch_alarm_names"></a> [deployment\_cloudwatch\_alarm\_names](#input\_deployment\_cloudwatch\_alarm\_names) | CloudWatch alarm names. | `list(string)` | `[]` | no |
| <a name="input_deployment_cloudwatch_alarm_rollback"></a> [deployment\_cloudwatch\_alarm\_rollback](#input\_deployment\_cloudwatch\_alarm\_rollback) | Enable rollback on alarm trigger. | `bool` | `false` | no |
| <a name="input_deployment_max_percent"></a> [deployment\_max\_percent](#input\_deployment\_max\_percent) | Maximum percentage of tasks during deployment. | `number` | `200` | no |
| <a name="input_deployment_min_healthy"></a> [deployment\_min\_healthy](#input\_deployment\_min\_healthy) | Minimum healthy percent during deployment. | `number` | `100` | no |
| <a name="input_deployment_rollback"></a> [deployment\_rollback](#input\_deployment\_rollback) | Enable automatic rollback on failure. | `bool` | `false` | no |
| <a name="input_ecs_cluster_name"></a> [ecs\_cluster\_name](#input\_ecs\_cluster\_name) | Name of the ECS cluster. | `string` | n/a | yes |
| <a name="input_ecs_launch_type"></a> [ecs\_launch\_type](#input\_ecs\_launch\_type) | Launch type for the ECS service (e.g., 'FARGATE' or 'EC2'). | `string` | `"FARGATE"` | no |
| <a name="input_ecs_service_name"></a> [ecs\_service\_name](#input\_ecs\_service\_name) | Name of the ECS service. | `string` | n/a | yes |
| <a name="input_ecs_task_count"></a> [ecs\_task\_count](#input\_ecs\_task\_count) | Desired number of running tasks in the ECS service. | `number` | `1` | no |
| <a name="input_ecs_task_cpu"></a> [ecs\_task\_cpu](#input\_ecs\_task\_cpu) | CPU units allocated for the ECS task. | `number` | `256` | no |
| <a name="input_ecs_task_memory"></a> [ecs\_task\_memory](#input\_ecs\_task\_memory) | Memory allocated for the ECS task (in MB). | `number` | `512` | no |
| <a name="input_enable_autoscaling"></a> [enable\_autoscaling](#input\_enable\_autoscaling) | Enable auto-scaling for the ECS service. | `bool` | `false` | no |
| <a name="input_enable_target_group"></a> [enable\_target\_group](#input\_enable\_target\_group) | Enable target group creation. | `bool` | `false` | no |
| <a name="input_health_check_interval_sec"></a> [health\_check\_interval\_sec](#input\_health\_check\_interval\_sec) | Time interval between health checks (in seconds). | `number` | `30` | no |
| <a name="input_health_check_matcher"></a> [health\_check\_matcher](#input\_health\_check\_matcher) | String to match against the response body for a successful health check. | `string` | `"200"` | no |
| <a name="input_health_check_path"></a> [health\_check\_path](#input\_health\_check\_path) | Path for health check requests. | `string` | `"/"` | no |
| <a name="input_health_check_protocol"></a> [health\_check\_protocol](#input\_health\_check\_protocol) | Protocol for health checks. | `string` | `"HTTP"` | no |
| <a name="input_health_check_threshold_healthy"></a> [health\_check\_threshold\_healthy](#input\_health\_check\_threshold\_healthy) | Number of successful checks before a target is considered healthy. | `number` | `3` | no |
| <a name="input_health_check_threshold_unhealthy"></a> [health\_check\_threshold\_unhealthy](#input\_health\_check\_threshold\_unhealthy) | Number of failed checks before a target is considered unhealthy. | `number` | `2` | no |
| <a name="input_health_check_timeout_sec"></a> [health\_check\_timeout\_sec](#input\_health\_check\_timeout\_sec) | Timeout for health check responses (in seconds). | `number` | `5` | no |
| <a name="input_host_based_routing"></a> [host\_based\_routing](#input\_host\_based\_routing) | List of host-based routing rules. | <pre>list(object({<br/>    host     = string<br/>    priority = number<br/>  }))</pre> | `[]` | no |
| <a name="input_lb_listener_arn"></a> [lb\_listener\_arn](#input\_lb\_listener\_arn) | ARN of the Load Balancer listener. | `string` | `null` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Number of days to retain log events in the CloudWatch log group. | `number` | `7` | no |
| <a name="input_max_task_count"></a> [max\_task\_count](#input\_max\_task\_count) | Maximum number of running tasks. | `number` | `10` | no |
| <a name="input_min_task_count"></a> [min\_task\_count](#input\_min\_task\_count) | Minimum number of running tasks. | `number` | `1` | no |
| <a name="input_path_based_routing"></a> [path\_based\_routing](#input\_path\_based\_routing) | List of path-based routing rules. | <pre>list(object({<br/>    path     = string<br/>    priority = number<br/>  }))</pre> | `[]` | no |
| <a name="input_queue_name"></a> [queue\_name](#input\_queue\_name) | Queue name for scaling. | `string` | `""` | no |
| <a name="input_queue_scale_in_threshold"></a> [queue\_scale\_in\_threshold](#input\_queue\_scale\_in\_threshold) | Number of messages in the queue that triggers scaling in (reducing tasks). | `number` | `10` | no |
| <a name="input_queue_scale_out_threshold"></a> [queue\_scale\_out\_threshold](#input\_queue\_scale\_out\_threshold) | Number of messages in the queue that triggers scaling out (increasing tasks). | `number` | `100` | no |
| <a name="input_scale_by_alarm_in_adjustment"></a> [scale\_by\_alarm\_in\_adjustment](#input\_scale\_by\_alarm\_in\_adjustment) | The adjustment for scaling in by alarm. | `number` | `-1` | no |
| <a name="input_scale_by_alarm_out_adjustment"></a> [scale\_by\_alarm\_out\_adjustment](#input\_scale\_by\_alarm\_out\_adjustment) | The adjustment for scaling out by alarm. | `number` | `1` | no |
| <a name="input_scale_cooldown_in_sec"></a> [scale\_cooldown\_in\_sec](#input\_scale\_cooldown\_in\_sec) | Cooldown period (seconds) before scaling in. | `number` | `300` | no |
| <a name="input_scale_cooldown_out_sec"></a> [scale\_cooldown\_out\_sec](#input\_scale\_cooldown\_out\_sec) | Cooldown period (seconds) before scaling out. | `number` | `300` | no |
| <a name="input_scale_on_alarm_usage"></a> [scale\_on\_alarm\_usage](#input\_scale\_on\_alarm\_usage) | Enable auto-scaling based on CloudWatch alarms. | `bool` | `false` | no |
| <a name="input_scale_on_cpu_target"></a> [scale\_on\_cpu\_target](#input\_scale\_on\_cpu\_target) | Target CPU utilization percentage for scaling. | `number` | `50` | no |
| <a name="input_scale_on_cpu_usage"></a> [scale\_on\_cpu\_usage](#input\_scale\_on\_cpu\_usage) | Enable auto-scaling based on CPU usage. | `bool` | `false` | no |
| <a name="input_scale_on_memory_target"></a> [scale\_on\_memory\_target](#input\_scale\_on\_memory\_target) | Target memory utilization percentage for scaling. | `number` | `50` | no |
| <a name="input_scale_on_memory_usage"></a> [scale\_on\_memory\_usage](#input\_scale\_on\_memory\_usage) | Enable auto-scaling based on memory usage. | `bool` | `false` | no |
| <a name="input_security_group_ids"></a> [security\_group\_ids](#input\_security\_group\_ids) | List of security groups attached to the ECS service. | `list(string)` | `[]` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | List of subnets for the ECS service. | `list(string)` | `[]` | no |
| <a name="input_target_group_name"></a> [target\_group\_name](#input\_target\_group\_name) | Name of the target group. | `string` | `"target-group"` | no |
| <a name="input_target_group_port"></a> [target\_group\_port](#input\_target\_group\_port) | Port exposed by the target group. | `number` | `80` | no |
| <a name="input_target_group_protocol"></a> [target\_group\_protocol](#input\_target\_group\_protocol) | Protocol used by the target group (HTTP/HTTPS). | `string` | `"HTTP"` | no |
| <a name="input_target_group_type"></a> [target\_group\_type](#input\_target\_group\_type) | Type of target group (IP/INSTANCE). | `string` | `"ip"` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of the VPC where the ECS service is deployed. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cloudwatch_log_group_name"></a> [cloudwatch\_log\_group\_name](#output\_cloudwatch\_log\_group\_name) | n/a |
| <a name="output_ecs_service_name"></a> [ecs\_service\_name](#output\_ecs\_service\_name) | n/a |
| <a name="output_ecs_task_definition_arn"></a> [ecs\_task\_definition\_arn](#output\_ecs\_task\_definition\_arn) | n/a |
| <a name="output_target_group_arn"></a> [target\_group\_arn](#output\_target\_group\_arn) | n/a |
<!-- END_TF_DOCS -->