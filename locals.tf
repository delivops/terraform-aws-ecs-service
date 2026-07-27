locals {
  # Common tags applied to all taggable resources
  common_tags = merge(
    { Application = var.ecs_service_name },
    var.tags
  )

  # Effective shared role ARN: the module-created role wins when
  # role.create = true, otherwise fall back to initial_role (or null).
  service_role_arn = var.role.create ? aws_iam_role.this[0].arn : (var.initial_role != "" ? var.initial_role : null)

  # Effective task/execution role ARNs. An explicit task_role_arn/execution_role_arn
  # wins (allowing distinct roles); otherwise both fall back to the shared role,
  # preserving the previous single-identity behavior.
  task_role_arn      = var.task_role_arn != "" ? var.task_role_arn : local.service_role_arn
  execution_role_arn = var.execution_role_arn != "" ? var.execution_role_arn : local.service_role_arn

  # Target group naming logic with 32-char safety
  main_target_group_name = var.application_load_balancer.target_group_name != "" ? var.application_load_balancer.target_group_name : replace(
    "${substr(var.ecs_service_name, 0, 20)}-${substr(md5("${data.aws_ecs_cluster.ecs_cluster.cluster_name}-${var.ecs_service_name}"), 0, 5)}-tg",
    "_", "-"
  )

  # Additional target group names with index
  additional_target_group_names = {
    for idx, alb in var.additional_load_balancers : idx => (
      alb.target_group_name != "" ? alb.target_group_name : replace(
        "${substr(var.ecs_service_name, 0, 18)}-${substr(md5("${data.aws_ecs_cluster.ecs_cluster.cluster_name}-${var.ecs_service_name}-${idx}"), 0, 5)}-tg-${idx}",
        "_", "-"
      )
    )
  }

  # Determine which port configuration to use
  use_alb             = var.application_load_balancer.enabled && var.application_load_balancer.action_type == "forward"
  use_service_connect = var.service_connect.enabled && !local.use_alb

  # Force numeric conversion
  alb_port = local.use_alb ? floor(var.application_load_balancer.container_port + 0) : 0
  sc_port  = local.use_service_connect ? floor(var.service_connect.port + 0) : 0

  # Effective container port, and whether to advertise appProtocol = http.
  # (Service Connect with appProtocol = "tcp" omits appProtocol from the mapping.)
  container_port     = local.use_alb ? local.alb_port : (local.use_service_connect ? local.sc_port : 0)
  include_http_proto = local.use_alb || (local.use_service_connect && var.service_connect.appProtocol == "http")

  # Port mappings for the container definition
  port_mappings = (local.use_alb || local.use_service_connect) ? [
    merge(
      {
        name          = "default"
        containerPort = local.container_port
        hostPort      = local.container_port
        protocol      = "tcp"
      },
      local.include_http_proto ? { appProtocol = "http" } : {}
    )
  ] : []

  # GPU resource requirements (only emitted when gpu_count > 0)
  gpu_resource_requirements = var.gpu_count > 0 ? [
    { type = "GPU", value = tostring(var.gpu_count) }
  ] : []

  # Build the complete container definition and encode it as JSON.
  # jsonencode() is used (instead of hand-built strings) so special characters
  # in container_name/container_image are escaped correctly.
  #
  # NOTE: this is only the INITIAL task-definition revision. aws_ecs_task_definition
  # has lifecycle { ignore_changes = all }, so the CI deploy pipeline owns the real
  # revision — including logConfiguration, secrets, environment, and (for GPUs)
  # resourceRequirements. Changing gpu_count here affects only the initial revision.
  container_definitions = [
    merge(
      {
        name         = var.container_name
        image        = var.container_image
        essential    = true
        portMappings = local.port_mappings
      },
      var.gpu_count > 0 ? { resourceRequirements = local.gpu_resource_requirements } : {}
    )
  ]

  container_definitions_json = jsonencode(local.container_definitions)
}
