
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

  # Build the primary port mapping
  primary_port_mapping = (
    var.application_load_balancer.enabled && var.application_load_balancer.action_type == "forward" ? [{
      name          = "default"
      containerPort = var.application_load_balancer.container_port
      hostPort      = var.application_load_balancer.container_port
      protocol      = "tcp"
      appProtocol   = "http"
    }] :
    var.service_connect.enabled && !(var.application_load_balancer.enabled && var.application_load_balancer.action_type == "forward") ? 
    (lookup(var.service_connect, "appProtocol", "http") == "http" ? [{
      name          = "default"
      containerPort = var.service_connect.port
      hostPort      = var.service_connect.port
      protocol      = "tcp"
      appProtocol   = "http"
    }] : [{
      name          = "default"
      containerPort = var.service_connect.port
      hostPort      = var.service_connect.port
      protocol      = "tcp"
    }]) : []
  )
  
  # Build additional port mappings
  additional_port_mappings = [
    for port_config in var.service_connect.additional_ports :
    lookup(port_config, "appProtocol", "http") == "http" ? {
      name          = port_config.name
      containerPort = port_config.port
      hostPort      = port_config.port
      protocol      = "tcp"
      appProtocol   = "http"
    } : {
      name          = port_config.name
      containerPort = port_config.port
      hostPort      = port_config.port
      protocol      = "tcp"
    }
  ]
  
  # Combine all port mappings
  all_port_mappings = concat(local.primary_port_mapping, local.additional_port_mappings)

}
