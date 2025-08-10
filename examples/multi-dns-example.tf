# Example showing various DNS configurations with the ECS service module

terraform {
  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
  }
}

# Default Cloudflare provider (dummy token - used by modules without provider override)
provider "cloudflare" {
  api_token = "1234567890abcdef1234567890abcdef12345678"
}

# Real Cloudflare provider configuration (for modules that need real credentials)
provider "cloudflare" {
  alias     = "real"
  api_token = var.cloudflare_api_token
}

# Example 1: Service with Route53 DNS only
module "ecs_service_route53_only" {
  source             = "../"
  ecs_cluster_name   = var.cluster_name
  ecs_service_name   = "route53-only"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids
  initial_role       = aws_iam_role.ecs_task_role.name

  application_load_balancer = {
    enabled               = true
    container_port        = 80
    listener_arn          = var.listener_arn
    host                  = "api-r53.example.com"
    path                  = "/*"
    health_check_path     = "/health"
    route_53_host_zone_id = var.route_53_zone_id
  }
}

# Example 2: Service with Cloudflare DNS only (proxied) - Uses REAL API token
module "ecs_service_cloudflare_proxied" {
  source             = "../"
  ecs_cluster_name   = var.cluster_name
  ecs_service_name   = "cloudflare-proxied"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids
  initial_role       = aws_iam_role.ecs_task_role.name

  providers = {
    cloudflare = cloudflare.real
  }

  application_load_balancer = {
    enabled            = true
    container_port     = 80
    listener_arn       = var.listener_arn
    host               = "api-cf.example.com"
    path               = "/*"
    health_check_path  = "/health"
    cloudflare_zone_id = var.cloudflare_zone_id
    cloudflare_proxied = true # Enable Cloudflare proxy features
  }
}

# Example 3: Service with Cloudflare DNS only (DNS-only mode) - Uses DUMMY token (no provider override)
module "ecs_service_cloudflare_dns_only" {
  source             = "../"
  ecs_cluster_name   = var.cluster_name
  ecs_service_name   = "cloudflare-dns-only"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids
  initial_role       = aws_iam_role.ecs_task_role.name

  # No providers block = uses default provider with dummy token

  application_load_balancer = {
    enabled            = true
    container_port     = 80
    listener_arn       = var.listener_arn
    host               = "api-dns.example.com"
    path               = "/*"
    health_check_path  = "/health"
    cloudflare_zone_id = var.cloudflare_zone_id
    cloudflare_proxied = false # DNS-only mode
  }
}

# Example 4: Service with both Route53 and Cloudflare DNS (dual setup)
module "ecs_service_dual_dns" {
  source             = "../"
  ecs_cluster_name   = var.cluster_name
  ecs_service_name   = "dual-dns"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids
  initial_role       = aws_iam_role.ecs_task_role.name

  application_load_balancer = {
    enabled               = true
    container_port        = 80
    listener_arn          = var.listener_arn
    host                  = "api-dual.example.com"
    path                  = "/*"
    health_check_path     = "/health"
    route_53_host_zone_id = var.route_53_zone_id
    cloudflare_zone_id    = var.cloudflare_zone_id
    cloudflare_proxied    = false # Use DNS-only for dual setup
  }
}

# Example 5: Service with multiple ALBs using different DNS providers
module "ecs_service_mixed_dns_providers" {
  source             = "../"
  ecs_cluster_name   = var.cluster_name
  ecs_service_name   = "mixed-dns"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids
  initial_role       = aws_iam_role.ecs_task_role.name

  # Main ALB with Cloudflare DNS
  application_load_balancer = {
    enabled            = true
    container_port     = 80
    listener_arn       = var.public_listener_arn
    host               = "api.example.com"
    path               = "/api/*"
    health_check_path  = "/health"
    cloudflare_zone_id = var.cloudflare_zone_id
    cloudflare_proxied = true
  }

  # Additional ALB with Route53 DNS for internal access
  additional_load_balancers = [
    {
      enabled               = true
      container_port        = 80
      listener_arn          = var.internal_listener_arn
      host                  = "api.internal.example.com"
      path                  = "/*"
      health_check_path     = "/health"
      route_53_host_zone_id = var.route_53_zone_id
    }
  ]
}

# Variables for the examples
variable "cloudflare_api_token" {
  description = "Cloudflare API token"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID"
  type        = string
}

variable "public_listener_arn" {
  description = "Public ALB listener ARN"
  type        = string
  default = ""
}

variable "internal_listener_arn" {
  description = "Internal ALB listener ARN"
  type        = string
  default = ""
}