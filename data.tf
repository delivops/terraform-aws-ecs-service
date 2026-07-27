data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_ecs_cluster" "ecs_cluster" {
  cluster_name = var.ecs_cluster_name
}

data "aws_service_discovery_http_namespace" "namespace" {
  count = var.service_connect.enabled ? 1 : 0
  name  = var.ecs_cluster_name
}

# Load balancer lookups are gated only on the ARN being resolvable, so the DNS
# name and zone id are always exported (see outputs.tf) and can be used to
# create DNS records (Route53, Cloudflare, etc.) outside this module.
#
# The ARN is resolved in locals.tf (local.main_lb_arn / local.additional_lb_arns)
# and covers both the ALB path (derived from listener_arn) and the NLB path
# (nlb_arn given directly).
data "aws_lb" "main_alb" {
  count = var.application_load_balancer.enabled && local.main_lb_arn != "" ? 1 : 0

  arn = local.main_lb_arn
}

data "aws_lb" "additional_albs" {
  for_each = local.additional_lb_arns_resolved

  arn = each.value
}
