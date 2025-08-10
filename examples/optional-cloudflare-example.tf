# Example: ECS Service with Optional Cloudflare DNS
# This example shows how to use the main module with optional Cloudflare DNS via submodule

# Main ECS service without Cloudflare dependencies
module "ecs_service" {
  source             = "../"
  ecs_cluster_name   = var.cluster_name
  ecs_service_name   = "cloudflare-optional-demo"
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
    # Note: No Cloudflare variables here - they're handled by the submodule
  }
}

# Optional Cloudflare DNS submodule (only runs if cloudflare_zone_id is provided)
module "cloudflare_dns" {
  count  = var.cloudflare_zone_id != "" ? 1 : 0
  source = "../modules/cloudflare-dns"

  ecs_service_name = "cloudflare-optional-demo"
  
  application_load_balancer = {
    enabled            = true
    host               = "api.delivops.com"
    cloudflare_zone_id = var.cloudflare_zone_id
    cloudflare_proxied = true
    cloudflare_ttl     = 300
    listener_arn       = var.listener_arn
  }

  additional_load_balancers = []
}

# Outputs
output "ecs_service_created" {
  description = "ECS service is always created"
  value       = true
}

output "cloudflare_dns_enabled" {
  description = "Whether Cloudflare DNS is enabled"
  value       = var.cloudflare_zone_id != ""
}

output "cloudflare_record_created" {
  description = "Whether Cloudflare record was created"
  value       = var.cloudflare_zone_id != "" ? module.cloudflare_dns[0].main_record_created : false
}

# Instructions:
# 1. Without Cloudflare: Set cloudflare_zone_id = "" in terraform.tfvars
#    - Only AWS resources are created
#    - No Cloudflare provider required
# 
# 2. With Cloudflare: Set cloudflare_zone_id = "your-zone-id" in terraform.tfvars
#    - AWS resources + Cloudflare DNS record created
#    - Requires CLOUDFLARE_API_TOKEN environment variable
