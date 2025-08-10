module "ecs_service_with_route53" {
  source             = "../"
  ecs_cluster_name   = var.cluster_name
  ecs_service_name   = "route53-demo"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids
  initial_role       = aws_iam_role.ecs_task_role.name

  application_load_balancer = {
    enabled               = true
    container_port        = 80
    listener_arn          = var.listener_arn
    host                  = "api.internal.delivops.com" # The domain name you want
    path                  = "/*"
    health_check_path     = "/"                  # Use root path for nginx
    route_53_host_zone_id = var.route_53_zone_id # Route 53 zone ID
  }
}
