module "ecs_service" {
  source = "./path/to/module"

  ecs_cluster_name = "my-cluster"
  ecs_service_name = "my-service"

  # Container configuration
  container_name  = "app-container"
  container_image = "my-app:latest"
  container_port  = 8080

  # Network configuration
  vpc_id             = "vpc-12345678"
  security_group_ids = ["sg-12345678"]
  subnet_ids         = ["subnet-12345678", "subnet-87654321"]

  # Target group configuration
  target_groups = [
    {
      name              = "app-tg-1"
      port              = 80
      protocol          = "HTTP"
      target_type       = "ip"
      health_check_path = "/health"
    },
    {
      name              = "app-tg-2"
      port              = 80
      protocol          = "HTTP"
      target_type       = "ip"
      health_check_path = "/api/health"
    }
  ]

  # Connect service to target groups
  service_target_groups = [
    {
      target_group_name = "app-tg-1"
      container_port    = 8080
    },
    {
      target_group_name = "app-tg-2"
      container_port    = 8080
    }
  ]

  # Routing rules
  host_based_routing = [
    {
      priority          = 100
      value             = "app1.example.com"
      target_group_name = "app-tg-1"
    }
  ]

  path_based_routing = [
    {
      priority          = 200
      value             = "/api/*"
      target_group_name = "app-tg-2"
    }
  ]

  # Load balancer configuration
  lb_listener_arn = "arn:aws:elasticloadbalancing:us-west-2:123456789012:listener/app/my-lb/1234567890abcdef/1234567890abcdef"

  # Other configurations...
}
