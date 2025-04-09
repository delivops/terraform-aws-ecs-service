data "aws_region" "current" {}

data "aws_ecs_cluster" "ecs_cluster" {
  cluster_name = var.ecs_cluster_name
}

data "aws_service_discovery_http_namespace" "namespace" {
  count = var.service_connect.enabled ? 1 : 0
  name  = var.ecs_cluster_name
}

data "external" "listener_rules" {
  count = var.application_load_balancer.enabled ? 1 : 0

  program = ["bash", "-c", <<EOT
    aws elbv2 describe-rules --listener-arn ${var.application_load_balancer.listener_arn} | \
    jq -c '{priorities: ([.Rules[].Priority | select(. != "default") | tostring] | join(","))}'
  EOT
  ]
}
