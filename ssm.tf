########################
# SSM Parameters
#########################
# Publish per-service metadata to SSM Parameter Store at predictable paths so the
# deploy pipeline can read them (e.g. to attach the roles to the real, CI-managed
# task definition).
#
# Note: tags are intentionally NOT published here. Task tagging is handled by
# tagging the ECS service (see aws_ecs_service.tags) together with
# propagate_tags = "SERVICE", so tasks inherit the service tags directly and the
# pipeline does not need to read tags from SSM.

# /ecs/<cluster>/<service>/task-role — the role the container assumes.
# Skipped when no task role is available.
resource "aws_ssm_parameter" "task_role" {
  count = local.has_task_role ? 1 : 0

  name  = "/ecs/${var.ecs_cluster_name}/${var.ecs_service_name}/task-role"
  type  = "String"
  value = local.task_role_arn
  tags  = local.common_tags
}

# /ecs/<cluster>/<service>/execution-role — the role the ECS agent assumes to
# start the task (ECR pull, log write, secret fetch).
resource "aws_ssm_parameter" "execution_role" {
  count = local.has_execution_role ? 1 : 0

  name  = "/ecs/${var.ecs_cluster_name}/${var.ecs_service_name}/execution-role"
  type  = "String"
  value = local.execution_role_arn
  tags  = local.common_tags
}
