# Clean Two-Module Approach: Main ECS + Optional Cloudflare DNS
# This example shows the cleanest way to use both modules without code duplication

# Step 1: Create your ECS service (main module)
module "ecs_service" {
  source             = "../"
  ecs_cluster_name   = var.cluster_name
  ecs_service_name   = "my-api"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  application_load_balancer = {
    enabled           = true
    container_port    = 80
    listener_arn      = var.listener_arn
    host              = "api.delivops.com"
    path              = "/*"
    health_check_path = "/"
    # Route 53 can still be used here if needed
    route_53_host_zone_id = var.route_53_zone_id
  }
}

# Step 2: Optionally add Cloudflare DNS (only if you want it)
module "cloudflare_dns" {
  count  = var.cloudflare_zone_id != "" ? 1 : 0
  source = "../modules/cloudflare-dns"

  ecs_service_name = "my-api"
  
  records = [
    {
      name    = "api.delivops.com"
      target  = module.ecs_service.alb_dns_info.dns_name
      zone_id = var.cloudflare_zone_id
      proxied = true
      comment = "Main API endpoint"
    }
    # Add more records if needed:
    # {
    #   name    = "api-v2.delivops.com"  
    #   target  = module.ecs_service.alb_dns_info.dns_name
    #   zone_id = var.cloudflare_zone_id
    #   proxied = false
    #   ttl     = 60
    # }
  ]
}

# Outputs
output "service_url" {
  description = "Service URL"
  value       = "https://api.delivops.com"
}

output "alb_dns_name" {
  description = "ALB DNS name (fallback)"
  value       = module.ecs_service.alb_dns_info.dns_name
}

output "cloudflare_records" {
  description = "Cloudflare DNS records created"
  value       = var.cloudflare_zone_id != "" ? module.cloudflare_dns[0].record_names : []
}

# Benefits of this approach:
# ✅ No code duplication
# ✅ Main module has no Cloudflare dependencies
# ✅ Cloudflare is truly optional
# ✅ Clean separation of concerns
# ✅ Easy to maintain
