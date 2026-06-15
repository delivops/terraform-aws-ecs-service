data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_ecs_cluster" "ecs_cluster" {
  cluster_name = var.ecs_cluster_name
}

data "aws_service_discovery_http_namespace" "namespace" {
  count = var.service_connect.enabled ? 1 : 0
  name  = var.ecs_cluster_name
}

# ALB lookups are gated only on the listener being set, so the DNS name and
# zone id are always exported (see outputs.tf) and can be used to create DNS
# records (Route53, Cloudflare, etc.) outside this module.
data "aws_lb" "main_alb" {
  count = var.application_load_balancer.enabled && var.application_load_balancer.listener_arn != "" ? 1 : 0

  # Extract ALB ARN from listener ARN by removing the listener part
  # From: arn:aws:elasticloadbalancing:us-east-1:556196322339:listener/app/production-alb/0477f09e7143a1db/398beeae51e94e2d
  # To:   arn:aws:elasticloadbalancing:us-east-1:556196322339:loadbalancer/app/production-alb/0477f09e7143a1db
  arn = replace(regex("^(.+)/[^/]+$", var.application_load_balancer.listener_arn)[0], ":listener/", ":loadbalancer/")
}

data "aws_lb" "additional_albs" {
  for_each = {
    for idx, alb in var.additional_load_balancers : idx => alb
    if alb.enabled && alb.listener_arn != ""
  }

  # Extract ALB ARN from listener ARN by removing the listener part
  arn = replace(regex("^(.+)/[^/]+$", each.value.listener_arn)[0], ":listener/", ":loadbalancer/")
}
