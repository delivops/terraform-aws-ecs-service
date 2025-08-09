module "ecs_service_with_cloudflare" {
  source             = "../"
  ecs_cluster_name   = var.cluster_name
  ecs_service_name   = "cloudflare-demo"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids
  initial_role       = aws_iam_role.ecs_task_role.name

  application_load_balancer = {
    enabled              = true
    container_port       = 80
    listener_arn         = var.listener_arn
    host                 = "api.example.com"           # The domain name you want
    path                 = "/*"
    health_check_path    = "/"                         # Use root path for nginx
    cloudflare_zone_id   = var.cloudflare_zone_id     # Cloudflare zone ID
    cloudflare_proxied   = true                        # Enable Cloudflare proxy (default: true)
    cloudflare_ttl       = 300                         # TTL in seconds (ignored when proxied=true)
  }
}

# Example with both Route53 and Cloudflare (for migration scenarios)
module "ecs_service_with_dual_dns" {
  source             = "../"
  ecs_cluster_name   = var.cluster_name
  ecs_service_name   = "dual-dns-demo"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids
  initial_role       = aws_iam_role.ecs_task_role.name

  application_load_balancer = {
    enabled               = true
    container_port        = 80
    listener_arn          = var.listener_arn
    host                  = "api.example.com"
    path                  = "/*"
    health_check_path     = "/"
    route_53_host_zone_id = var.route_53_zone_id      # Route 53 zone ID
    cloudflare_zone_id    = var.cloudflare_zone_id    # Cloudflare zone ID
    cloudflare_proxied    = false                      # Disable proxy for DNS-only mode
  }
}

# Example with multiple ALBs using different DNS providers
module "ecs_service_with_mixed_dns" {
  source             = "../"
  ecs_cluster_name   = var.cluster_name
  ecs_service_name   = "mixed-dns-demo"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids
  initial_role       = aws_iam_role.ecs_task_role.name

  application_load_balancer = {
    enabled               = true
    container_port        = 80
    listener_arn          = var.listener_arn
    host                  = "api.example.com"
    path                  = "/api/*"
    health_check_path     = "/health"
    cloudflare_zone_id    = var.cloudflare_zone_id
    cloudflare_proxied    = true
  }

  additional_load_balancers = [
    {
      enabled               = true
      container_port        = 80
      listener_arn          = var.admin_listener_arn
      host                  = "admin.internal.example.com"
      path                  = "/admin/*"
      health_check_path     = "/health"
      route_53_host_zone_id = var.route_53_zone_id      # Use Route53 for internal domain
    }
  ]
}