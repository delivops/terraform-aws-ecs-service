
locals {
  existing_priorities_string = var.application_load_balancer != {} && var.application_load_balancer.listener_arn != "" ? try(data.external.listener_rules[0].result.priorities, "") : ""
  existing_priorities        = local.existing_priorities_string != "" ? split(",", local.existing_priorities_string) : []

  max_priority  = length(local.existing_priorities) > 0 ? max(local.existing_priorities...) : 0
  next_priority = local.max_priority + 1

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

  scale_in_queue_name = (
    var.sqs_auto_scaling.queue_name != "" ?
    var.sqs_auto_scaling.queue_name :
    var.sqs_auto_scaling.scale_in_queue_name
  )

  scale_out_queue_name = (
    var.sqs_auto_scaling.queue_name != "" ?
    var.sqs_auto_scaling.queue_name :
    var.sqs_auto_scaling.scale_out_queue_name
  )


  # Determine which port configuration to use
  use_alb             = var.application_load_balancer.enabled && var.application_load_balancer.action_type == "forward"
  use_service_connect = var.service_connect.enabled && !local.use_alb

  # Force numeric conversion
  alb_port = local.use_alb ? floor(var.application_load_balancer.container_port + 0) : 0
  sc_port  = local.use_service_connect ? floor(var.service_connect.port + 0) : 0

  # Build port mappings as JSON string directly
  port_mappings_json = local.use_alb ? "[{\"name\":\"default\",\"containerPort\":${local.alb_port},\"hostPort\":${local.alb_port},\"protocol\":\"tcp\",\"appProtocol\":\"http\"}]" : (
    local.use_service_connect ? (
      lookup(var.service_connect, "appProtocol", "http") == "http" ?
      "[{\"name\":\"default\",\"containerPort\":${local.sc_port},\"hostPort\":${local.sc_port},\"protocol\":\"tcp\",\"appProtocol\":\"http\"}]" :
      "[{\"name\":\"default\",\"containerPort\":${local.sc_port},\"hostPort\":${local.sc_port},\"protocol\":\"tcp\"}]"
    ) : "[]"
  )

  # Build the complete container definition as JSON string
  container_definitions_json = "[{\"name\":\"${var.container_name}\",\"image\":\"${var.container_image}\",\"essential\":true,\"portMappings\":${local.port_mappings_json}}]"
}
