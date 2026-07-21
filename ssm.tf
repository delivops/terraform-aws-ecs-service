########################
# SSM Parameters
#########################
# Publish per-service metadata to SSM Parameter Store at predictable paths so the
# deploy pipeline can read them (e.g. to attach the role to the real, CI-managed
# task definition).
#
# Note: tags are intentionally NOT published here. Task tagging is handled by
# tagging the ECS service (see aws_ecs_service.tags) together with
# propagate_tags = "SERVICE", so tasks inherit the service tags directly and the
# pipeline does not need to read tags from SSM.

# /ecs/<cluster>/<service>/role — the task/execution role ARN.
# Skipped when no role is available (role.create = false AND initial_role = "").
resource "aws_ssm_parameter" "role" {
  count = local.service_role_arn != null ? 1 : 0

  name  = "/ecs/${var.ecs_cluster_name}/${var.ecs_service_name}/role"
  type  = "String"
  value = local.service_role_arn
  tags  = local.common_tags
}
