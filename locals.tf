
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

  # SQS Autoscaling queue name resolution
  sqs_out_queue = coalesce(
    try(var.sqs_autoscaling.scale_out_queue_name, null),
    try(var.sqs_autoscaling.queue_name, null)
  )
  sqs_in_queue = coalesce(
    try(var.sqs_autoscaling.scale_in_queue_name, null),
    try(var.sqs_autoscaling.queue_name, null)
  )

  # SQS Autoscaling defaults (hardcoded module best practices)
  sqs_require_empty_for_scale_in = coalesce(try(var.sqs_autoscaling.require_empty_for_scale_in, null), false)
  sqs_empty_eval_periods         = coalesce(try(var.sqs_autoscaling.empty_eval_periods, null), 3)
  sqs_empty_period_seconds       = coalesce(try(var.sqs_autoscaling.empty_period_seconds, null), 300)
  sqs_scale_out_cooldown         = coalesce(try(var.sqs_autoscaling.scale_out_cooldown, null), 60)
  sqs_scale_in_cooldown          = coalesce(try(var.sqs_autoscaling.scale_in_cooldown, null), 600)
  sqs_scale_in_step              = coalesce(try(var.sqs_autoscaling.scale_in_step, null), -1)
  sqs_aggregation_type_out       = coalesce(try(var.sqs_autoscaling.aggregation_type_out, null), "Average")
  sqs_aggregation_type_in        = coalesce(try(var.sqs_autoscaling.aggregation_type_in, null), "Average")
  sqs_treat_missing_out          = coalesce(try(var.sqs_autoscaling.treat_missing_out, null), "notBreaching")
  sqs_treat_missing_in           = coalesce(try(var.sqs_autoscaling.treat_missing_in, null), "ignore")
  sqs_age_sma_points             = coalesce(try(var.sqs_autoscaling.age_sma_points, null), 0)

  # Default scale-out step ladder if not provided
  sqs_scale_out_steps_default = [
    { lower = 0, upper = 100, change = 2 },
    { lower = 100, upper = 500, change = 5 },
    { lower = 500, upper = null, change = 15 }
  ]
  sqs_scale_out_steps = coalesce(
    try(var.sqs_autoscaling.scale_out_steps, null),
    local.sqs_scale_out_steps_default
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
