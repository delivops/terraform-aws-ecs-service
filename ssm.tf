########################
# SSM Parameters
#########################
# Publish per-service metadata to SSM Parameter Store at predictable paths so the
# deploy pipeline can read them (e.g. to attach the role to the real, CI-managed
# task definition and to apply the service tags).

# /ecs/<cluster>/<service>/role — the task/execution role ARN.
# Skipped when no role is available (role.create = false AND initial_role = "").
resource "aws_ssm_parameter" "role" {
  count = local.service_role_arn != null ? 1 : 0

  name  = "/ecs/${var.ecs_cluster_name}/${var.ecs_service_name}/role"
  type  = "String"
  value = local.service_role_arn
  tags  = local.common_tags
}

# /ecs/<cluster>/<service>/tags — the effective tags ({ Application } merged with var.tags), JSON-encoded.
resource "aws_ssm_parameter" "tags" {
  name  = "/ecs/${var.ecs_cluster_name}/${var.ecs_service_name}/tags"
  type  = "String"
  value = jsonencode(local.common_tags)
  tags  = local.common_tags
}
