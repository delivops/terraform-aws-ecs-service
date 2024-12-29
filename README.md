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
