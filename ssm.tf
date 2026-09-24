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

# /ecs/<cluster>/<service>/task-definition-template — the family the deploy
# pipeline copies the latest revision from.
resource "aws_ssm_parameter" "task_definition_template" {
  count = var.task_definition_template.enabled ? 1 : 0

  name  = "/ecs/${var.ecs_cluster_name}/${var.ecs_service_name}/task-definition-template"
  type  = "String"
  value = aws_ecs_task_definition.template[0].family
  tags  = local.common_tags
}

# /ecs/<cluster>/<service>/replica-count — the desired count the deploy pipeline
# sets on the service. Absent when the count is left to an autoscaler.
resource "aws_ssm_parameter" "task_definition_template_replica_count" {
  count = var.task_definition_template.enabled && var.task_definition_template.replica_count != null ? 1 : 0

  name  = "/ecs/${var.ecs_cluster_name}/${var.ecs_service_name}/replica-count"
  type  = "String"
  value = tostring(var.task_definition_template.replica_count)
  tags  = local.common_tags
}
