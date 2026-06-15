# Example showing DNS configurations with the ECS service module.
#
# This module manages Route53 records natively. It no longer manages Cloudflare
# records or configures a Cloudflare provider. If you use Cloudflare, create the
# records in your own configuration using the module's `load_balancer` output.

# Example 1: Service with Route53 DNS (managed by the module)
module "ecs_service_route53" {
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

# Example 2: Service fronted by an ALB, with Cloudflare DNS managed OUTSIDE the
# module. The module exposes the ALB DNS name via the `load_balancer` output, so
# you own the Cloudflare provider and record in your root configuration.
module "ecs_service_for_cloudflare" {
  source             = "../"
  ecs_cluster_name   = var.cluster_name
  ecs_service_name   = "cloudflare-demo"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids
  initial_role       = aws_iam_role.ecs_task_role.name

  application_load_balancer = {
    enabled           = true
    container_port    = 80
    listener_arn      = var.listener_arn
    host              = "api-cf.example.com"
    path              = "/*"
    health_check_path = "/health"
    # No route_53_host_zone_id: we manage DNS in Cloudflare below.
  }
}

# Cloudflare provider and record live in YOUR configuration, not the module.
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

resource "cloudflare_record" "api" {
  zone_id = var.cloudflare_zone_id
  name    = "api-cf.example.com"
  content = module.ecs_service_for_cloudflare.load_balancer.main.dns_name
  type    = "CNAME"
  proxied = true
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

variable "route_53_zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
}

# Common variables (should be defined in examples/variables.tf)
variable "cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs"
  type        = list(string)
}

variable "listener_arn" {
  description = "ALB listener ARN"
  type        = string
}
