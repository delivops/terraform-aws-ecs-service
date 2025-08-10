# Example: Single module call for ECS service with optional Cloudflare DNS
# This shows how to use the wrapper module that handles both ECS and Cloudflare in one call

module "my_service" {
  source = "../modules/ecs-service-with-dns"

  # Core service configuration
  ecs_cluster_name   = var.cluster_name
  ecs_service_name   = "my-web-app"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  # Container configuration
  container_image = "nginx:latest"
  container_name  = "web"
  desired_count   = 2
  ecs_task_cpu    = 256
  ecs_task_memory = 512

  # Load balancer with optional Cloudflare DNS
  application_load_balancer = {
    enabled           = true
    container_port    = 80
    listener_arn      = var.listener_arn
    host              = "my-app.example.com"
    path              = "/*"
    health_check_path = "/"
    
    # Cloudflare DNS (optional - remove these lines to disable Cloudflare)
    cloudflare_zone_id = var.cloudflare_zone_id  # Set to "" to disable
    cloudflare_proxied = true
    cloudflare_ttl     = 300
  }

  # Additional load balancers (also with optional Cloudflare)
  additional_load_balancers = [
    {
      enabled           = true
      container_port    = 8080
      listener_arn      = var.listener_arn  # Use same listener or create var.api_listener_arn
      host              = "api.example.com"
      path              = "/api/*"
      health_check_path = "/health"
      
      # This one also gets Cloudflare DNS
      cloudflare_zone_id = var.cloudflare_zone_id
      cloudflare_proxied = false
      cloudflare_ttl     = 600
    },
    {
      enabled           = true
      container_port    = 9090
      listener_arn      = var.listener_arn  # Use same listener or create var.metrics_listener_arn
      host              = "metrics.example.com"
      path              = "/metrics/*"
      health_check_path = "/metrics/health"
      
      # This one doesn't use Cloudflare (empty zone_id)
      cloudflare_zone_id = ""
    }
  ]

  tags = {
    Environment = "production"
    Service     = "web-app"
  }
}

# Outputs from the wrapper module
output "ecs_service_name" {
  description = "Name of the created ECS service"
  value       = module.my_service.ecs_service_name
}

output "ecs_service_arn" {
  description = "ARN of the created ECS service"
  value       = module.my_service.ecs_service_arn
}

output "cloudflare_records" {
  description = "Cloudflare DNS records created (if any)"
  value       = module.my_service.cloudflare_records
}

output "cloudflare_enabled" {
  description = "Whether Cloudflare DNS was enabled"
  value       = module.my_service.cloudflare_enabled
}
