locals {
  # Common tags applied to all taggable resources
  common_tags = merge(
    { Application = var.ecs_service_name },
    var.tags
  )

  # Effective task/execution role ARN: the module-created role wins when
  # role.create = true, otherwise fall back to initial_role (or null).
  service_role_arn = var.role.create ? aws_iam_role.this[0].arn : (var.initial_role != "" ? var.initial_role : null)

  # Derived from configuration rather than from service_role_arn, because
  # aws_iam_role.this[0].arn is unknown at plan time until the role exists, and
  # a count derived from an unknown value fails the plan. Anything using this as
  # a count or for_each must not switch to testing the ARN.
  has_service_role = var.role.create || var.initial_role != ""

  # An explicit task_role_arn/execution_role_arn allows the two identities to
  # differ; otherwise both fall back to the shared role.
  task_role_arn      = var.task_role_arn != "" ? var.task_role_arn : local.service_role_arn
  execution_role_arn = var.execution_role_arn != "" ? var.execution_role_arn : local.service_role_arn

  has_task_role      = var.task_role_arn != "" || local.has_service_role
  has_execution_role = var.execution_role_arn != "" || local.has_service_role

  # awsvpc tasks get their own ENI and register with the target group by IP;
  # bridge and host tasks share the instance network stack and register by
  # instance id.
  target_group_target_type = var.network_mode == "awsvpc" ? "ip" : "instance"

  # HTTP callers pass a listener ARN, from which the load balancer ARN is
  # derived. TCP callers pass nlb_arn directly, because the module creates the
  # listener itself and there is no caller-supplied listener ARN to derive from.
  # regexall rather than regex: this is evaluated unconditionally, and regex
  # raises an error when listener_arn is "".
  listener_arn_pattern = "^(.+)/[^/]+$"

  main_lb_arn_from_listener = length(regexall(local.listener_arn_pattern, var.application_load_balancer.listener_arn)) > 0 ? replace(
    regexall(local.listener_arn_pattern, var.application_load_balancer.listener_arn)[0][0],
    ":listener/", ":loadbalancer/"
  ) : ""

  main_lb_arn = var.application_load_balancer.protocol == "TCP" ? var.application_load_balancer.nlb_arn : local.main_lb_arn_from_listener

  additional_lb_arns = {
    for idx, alb in var.additional_load_balancers : idx => (
      alb.protocol == "TCP" ? alb.nlb_arn : (
        length(regexall(local.listener_arn_pattern, alb.listener_arn)) > 0 ? replace(
          regexall(local.listener_arn_pattern, alb.listener_arn)[0][0],
          ":listener/", ":loadbalancer/"
        ) : ""
      )
    )
  }

  # Drives the aws_lb data source's for_each, so its keys and every consumer's
  # keys stay in lockstep.
  additional_lb_arns_resolved = {
    for idx, alb in var.additional_load_balancers : idx => local.additional_lb_arns[idx]
    if alb.enabled && local.additional_lb_arns[idx] != ""
  }

  # An alias record needs dns_name/zone_id from the aws_lb data source, so it can
  # only be created where that data source exists.
  create_main_route53_record = (
    var.application_load_balancer.enabled &&
    var.application_load_balancer.route_53_host_zone_id != "" &&
    var.application_load_balancer.host != "" &&
    local.main_lb_arn != ""
  )

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
  # Service Connect with appProtocol = "tcp" omits appProtocol from the mapping.
  container_port     = local.use_alb ? local.alb_port : (local.use_service_connect ? local.sc_port : 0)
  include_http_proto = local.use_alb || (local.use_service_connect && var.service_connect.appProtocol == "http")

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

  # jsonencode rather than a hand-built string, so characters that are special
  # in JSON are escaped correctly in container_name and container_image.
  container_definitions = [
    {
      name         = var.container_name
      image        = var.container_image
      essential    = true
      portMappings = local.port_mappings
    }
  ]

  container_definitions_json = jsonencode(local.container_definitions)
}