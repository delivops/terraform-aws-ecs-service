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

  # Whether a role ARN will exist, derived from *configuration* only.
  #
  # These mirror the conditions above but must never reference the ARNs
  # themselves: when role.create = true and the role is not yet in state,
  # aws_iam_role.this[0].arn is unknown at plan time, so `arn != null` is also
  # unknown. Using that as a `count` makes the count unknown and Terraform
  # refuses to plan ("the count value depends on resource attributes that
  # cannot be determined until apply"), which breaks the very first apply of a
  # service using role.create. Anything consuming these as a count/for_each
  # must use the booleans below, not the ARNs.
  has_shared_role    = var.role.create || var.initial_role != ""
  has_task_role      = var.task_role_arn != "" || local.has_shared_role
  has_execution_role = var.execution_role_arn != "" || local.has_shared_role

  # Target group target type must match the task network mode: awsvpc tasks get
  # their own ENI and register by IP, whereas bridge/host tasks share the
  # instance's network stack and register by instance id. Fargate is always
  # awsvpc (enforced in variables.tf), so this only ever differs for EC2.
  target_group_target_type = var.network_mode == "awsvpc" ? "ip" : "instance"

  # Load balancer ARN resolution.
  #
  # Two shapes are supported and they carry the ARN differently:
  #   HTTP (ALB) — the caller passes a *listener* ARN; the load balancer ARN is
  #                derived from it by stripping the listener suffix.
  #   TCP  (NLB) — the caller passes nlb_arn directly, because the module
  #                creates the listener itself (aws_lb_listener.tcp_listener)
  #                and so there is no caller-supplied listener ARN to derive from.
  #
  # regexall() rather than regex(): these locals are evaluated unconditionally,
  # and regex() raises an error when the string does not match (e.g. when
  # listener_arn is ""), whereas regexall() simply returns [].
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

  # Additional load balancers whose ARN could actually be resolved. Used as the
  # for_each of the aws_lb data source so that its keys and the keys of every
  # consumer stay in lockstep.
  additional_lb_arns_resolved = {
    for idx, alb in var.additional_load_balancers : idx => local.additional_lb_arns[idx]
    if alb.enabled && local.additional_lb_arns[idx] != ""
  }

  # A Route53 alias record needs the load balancer's dns_name/zone_id, which
  # come from the aws_lb data source — so the record can only be created when
  # that data source exists. Guarding on the resolved ARN (rather than on
  # listener_arn alone) keeps the record and the data source in agreement for
  # the NLB path too.
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
