data "aws_region" "current" {}

data "aws_ecs_cluster" "ecs_cluster" {
  cluster_name = var.ecs_cluster_name
}

data "external" "listener_rules" {
  count = var.application_load_balancer != {} && var.application_load_balancer.listener_arn != "" ? 1 : 0

  program = ["bash", "-c", <<EOT
    aws elbv2 describe-rules --listener-arn ${var.application_load_balancer.listener_arn} | \
    jq -c '{priorities: ([.Rules[].Priority | select(. != "default") | tostring] | join(","))}'
  EOT
  ]
}
