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
| <a name="input_assign_public_ip"></a> [assign\_public\_ip](#input\_assign\_public\_ip) | Whether to assign a public IP. | `bool` | `true` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | The Name of the ECS cluster. | `string` | n/a | yes |
| <a name="input_container_image"></a> [container\_image](#input\_container\_image) | The image of the container. | `string` | `"nginx:stable"` | no |
| <a name="input_container_name"></a> [container\_name](#input\_container\_name) | The name of the container. | `string` | `"app"` | no |
| <a name="input_container_port"></a> [container\_port](#input\_container\_port) | The port of the container. | `number` | `80` | no |
| <a name="input_deployment_circuit_breaker_enabled"></a> [deployment\_circuit\_breaker\_enabled](#input\_deployment\_circuit\_breaker\_enabled) | Whether to enable deployment circuit breaker. | `bool` | `false` | no |
| <a name="input_deployment_circuit_breaker_rollback_enabled"></a> [deployment\_circuit\_breaker\_rollback\_enabled](#input\_deployment\_circuit\_breaker\_rollback\_enabled) | Whether to enable deployment circuit breaker. | `bool` | `false` | no |
| <a name="input_deployment_cloudwatch_alarm_enabled"></a> [deployment\_cloudwatch\_alarm\_enabled](#input\_deployment\_cloudwatch\_alarm\_enabled) | Whether to enable CloudWatch alarms. | `bool` | `false` | no |
| <a name="input_deployment_cloudwatch_alarm_names"></a> [deployment\_cloudwatch\_alarm\_names](#input\_deployment\_cloudwatch\_alarm\_names) | The CloudWatch alarm names. | `list(string)` | `[]` | no |
| <a name="input_deployment_cloudwatch_alarm_rollback_enabled"></a> [deployment\_cloudwatch\_alarm\_rollback\_enabled](#input\_deployment\_cloudwatch\_alarm\_rollback\_enabled) | Whether to rollback on CloudWatch alarms. | `bool` | `false` | no |
| <a name="input_deployment_maximum_percent"></a> [deployment\_maximum\_percent](#input\_deployment\_maximum\_percent) | The maximum percent for deployment. | `number` | `200` | no |
| <a name="input_deployment_minimum_healthy_percent"></a> [deployment\_minimum\_healthy\_percent](#input\_deployment\_minimum\_healthy\_percent) | The minimum healthy percent for deployment. | `number` | `100` | no |
| <a name="input_desired_count"></a> [desired\_count](#input\_desired\_count) | The desired count of the ECS service. | `number` | `1` | no |
| <a name="input_enable_target_group"></a> [enable\_target\_group](#input\_enable\_target\_group) | Whether the target group is enabled. | `bool` | `false` | no |
| <a name="input_execution_role_arn"></a> [execution\_role\_arn](#input\_execution\_role\_arn) | The ARN of the execution role. | `string` | `""` | no |
| <a name="input_health_check_healthy_threshold"></a> [health\_check\_healthy\_threshold](#input\_health\_check\_healthy\_threshold) | Healthy threshold for the health check. | `number` | `3` | no |
| <a name="input_health_check_interval"></a> [health\_check\_interval](#input\_health\_check\_interval) | Interval for the health check. | `number` | `30` | no |
| <a name="input_health_check_matcher"></a> [health\_check\_matcher](#input\_health\_check\_matcher) | Matcher for the health check. | `string` | `"200"` | no |
| <a name="input_health_check_path"></a> [health\_check\_path](#input\_health\_check\_path) | Path for the health check. | `string` | `"/"` | no |
| <a name="input_health_check_protocol"></a> [health\_check\_protocol](#input\_health\_check\_protocol) | Protocol for the health check. | `string` | `"HTTP"` | no |
| <a name="input_health_check_timeout"></a> [health\_check\_timeout](#input\_health\_check\_timeout) | The timeout for the health check. | `number` | `5` | no |
| <a name="input_health_check_unhealthy_threshold"></a> [health\_check\_unhealthy\_threshold](#input\_health\_check\_unhealthy\_threshold) | Unhealthy threshold for the health check. | `number` | `2` | no |
| <a name="input_host_rules"></a> [host\_rules](#input\_host\_rules) | Host rules for the listener. | <pre>list(object({<br/>    value    = string<br/>    priority = number<br/>  }))</pre> | `[]` | no |
| <a name="input_launch_type"></a> [launch\_type](#input\_launch\_type) | The launch type of the ECS service. | `string` | `"FARGATE"` | no |
| <a name="input_listener_arn"></a> [listener\_arn](#input\_listener\_arn) | ARN of the load balancer. | `string` | `null` | no |
| <a name="input_max_capacity"></a> [max\_capacity](#input\_max\_capacity) | Maximum number of tasks for scaling | `number` | `10` | no |
| <a name="input_min_capacity"></a> [min\_capacity](#input\_min\_capacity) | Minimum number of tasks for scaling | `number` | `1` | no |
| <a name="input_path_rules"></a> [path\_rules](#input\_path\_rules) | Path rules for the listener. | <pre>list(object({<br/>    value    = string<br/>    priority = number<br/>  }))</pre> | `[]` | no |
| <a name="input_queue_name"></a> [queue\_name](#input\_queue\_name) | The name of the SQS queue. | `string` | `""` | no |
| <a name="input_scale_by_alarm_enabled"></a> [scale\_by\_alarm\_enabled](#input\_scale\_by\_alarm\_enabled) | Whether to enable scaling by alarm. | `bool` | `false` | no |
| <a name="input_scale_by_alarm_in_adjustment"></a> [scale\_by\_alarm\_in\_adjustment](#input\_scale\_by\_alarm\_in\_adjustment) | The adjustment for scaling in by alarm. | `number` | `-1` | no |
| <a name="input_scale_by_alarm_in_cooldown"></a> [scale\_by\_alarm\_in\_cooldown](#input\_scale\_by\_alarm\_in\_cooldown) | The cooldown for scaling in by alarm. | `number` | `300` | no |
| <a name="input_scale_by_alarm_in_name"></a> [scale\_by\_alarm\_in\_name](#input\_scale\_by\_alarm\_in\_name) | The name of the in alarm. | `string` | `""` | no |
| <a name="input_scale_by_alarm_in_threshold"></a> [scale\_by\_alarm\_in\_threshold](#input\_scale\_by\_alarm\_in\_threshold) | The target value for scaling in by alarm. | `number` | `15` | no |
| <a name="input_scale_by_alarm_out_adjustment"></a> [scale\_by\_alarm\_out\_adjustment](#input\_scale\_by\_alarm\_out\_adjustment) | The adjustment for scaling out by alarm. | `number` | `1` | no |
| <a name="input_scale_by_alarm_out_cooldown"></a> [scale\_by\_alarm\_out\_cooldown](#input\_scale\_by\_alarm\_out\_cooldown) | The cooldown for scaling out by alarm. | `number` | `300` | no |
| <a name="input_scale_by_alarm_out_name"></a> [scale\_by\_alarm\_out\_name](#input\_scale\_by\_alarm\_out\_name) | The name of the out alarm. | `string` | `""` | no |
| <a name="input_scale_by_alarm_out_threshold"></a> [scale\_by\_alarm\_out\_threshold](#input\_scale\_by\_alarm\_out\_threshold) | The target value for scaling out by alarm. | `number` | `85` | no |
| <a name="input_scale_by_cpu_enabled"></a> [scale\_by\_cpu\_enabled](#input\_scale\_by\_cpu\_enabled) | Whether to enable scaling by CPU. | `bool` | `false` | no |
| <a name="input_scale_by_cpu_in_cooldown"></a> [scale\_by\_cpu\_in\_cooldown](#input\_scale\_by\_cpu\_in\_cooldown) | The cooldown for scaling in by CPU. | `number` | `300` | no |
| <a name="input_scale_by_cpu_out_cooldown"></a> [scale\_by\_cpu\_out\_cooldown](#input\_scale\_by\_cpu\_out\_cooldown) | The cooldown for scaling out by CPU. | `number` | `300` | no |
| <a name="input_scale_by_cpu_target_value"></a> [scale\_by\_cpu\_target\_value](#input\_scale\_by\_cpu\_target\_value) | The target value for scaling by CPU. | `number` | `50` | no |
| <a name="input_scale_by_memory_enabled"></a> [scale\_by\_memory\_enabled](#input\_scale\_by\_memory\_enabled) | Whether to enable scaling by memory. | `bool` | `false` | no |
| <a name="input_scale_by_memory_in_cooldown"></a> [scale\_by\_memory\_in\_cooldown](#input\_scale\_by\_memory\_in\_cooldown) | The cooldown for scaling in by memory. | `number` | `300` | no |
| <a name="input_scale_by_memory_out_cooldown"></a> [scale\_by\_memory\_out\_cooldown](#input\_scale\_by\_memory\_out\_cooldown) | The cooldown for scaling out by memory. | `number` | `300` | no |
| <a name="input_scale_by_memory_target_value"></a> [scale\_by\_memory\_target\_value](#input\_scale\_by\_memory\_target\_value) | The target value for scaling by memory. | `number` | `50` | no |
| <a name="input_scaling_enabled"></a> [scaling\_enabled](#input\_scaling\_enabled) | Whether to enable scaling. | `bool` | `false` | no |
| <a name="input_security_groups"></a> [security\_groups](#input\_security\_groups) | The security groups for the ECS service. | `list(string)` | `[]` | no |
| <a name="input_service_name"></a> [service\_name](#input\_service\_name) | The name of the ECS service. | `string` | n/a | yes |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | The subnets for the ECS service. | `list(string)` | `[]` | no |
| <a name="input_target_group_name"></a> [target\_group\_name](#input\_target\_group\_name) | The name of the target group. | `string` | `"target-group"` | no |
| <a name="input_target_group_port"></a> [target\_group\_port](#input\_target\_group\_port) | The port of the target group. | `number` | `80` | no |
| <a name="input_target_group_protocol"></a> [target\_group\_protocol](#input\_target\_group\_protocol) | The protocol of the target group. | `string` | `"HTTP"` | no |
| <a name="input_target_type"></a> [target\_type](#input\_target\_type) | The target type of the target group. | `string` | `"ip"` | no |
| <a name="input_task_role_arn"></a> [task\_role\_arn](#input\_task\_role\_arn) | The ARN of the task role. | `string` | `""` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | The VPC ID where the target group is located. | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cloudwatch_log_group_name"></a> [cloudwatch\_log\_group\_name](#output\_cloudwatch\_log\_group\_name) | n/a |
| <a name="output_ecs_service_name"></a> [ecs\_service\_name](#output\_ecs\_service\_name) | n/a |
| <a name="output_ecs_task_definition_arn"></a> [ecs\_task\_definition\_arn](#output\_ecs\_task\_definition\_arn) | n/a |
| <a name="output_target_group_arn"></a> [target\_group\_arn](#output\_target\_group\_arn) | n/a |
<!-- END_TF_DOCS -->