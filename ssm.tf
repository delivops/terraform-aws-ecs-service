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

# /ecs/<cluster>/<service>/role — legacy single role ARN (task == execution).
# Kept for backward compatibility. Falls back to the task or execution role so it
# is still published when only task_role_arn/execution_role_arn are set.
resource "aws_ssm_parameter" "role" {
  count = local.ssm_legacy_role_arn != null ? 1 : 0

  name  = "/ecs/${var.ecs_cluster_name}/${var.ecs_service_name}/role"
  type  = "String"
  value = local.ssm_legacy_role_arn
  tags  = local.common_tags
}

# /ecs/<cluster>/<service>/task-role — the task role ARN (application permissions).
resource "aws_ssm_parameter" "task_role" {
  count = local.task_role_arn != null ? 1 : 0

  name  = "/ecs/${var.ecs_cluster_name}/${var.ecs_service_name}/task-role"
  type  = "String"
  value = local.task_role_arn
  tags  = local.common_tags
}

# /ecs/<cluster>/<service>/execution-role — the execution role ARN (ECR pull,
# log write, secret fetch). A deploy pipeline can read this to register the real
# task definition with distinct task and execution roles.
resource "aws_ssm_parameter" "execution_role" {
  count = local.execution_role_arn != null ? 1 : 0

  name  = "/ecs/${var.ecs_cluster_name}/${var.ecs_service_name}/execution-role"
  type  = "String"
  value = local.execution_role_arn
  tags  = local.common_tags
}
