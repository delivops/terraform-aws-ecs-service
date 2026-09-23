resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name              = "/ecs/${data.aws_ecs_cluster.ecs_cluster.cluster_name}/${var.ecs_service_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.log_kms_key_id != "" ? var.log_kms_key_id : null
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_anomaly_detector" "this" {
  count                   = var.log_anomaly_detection.enabled ? 1 : 0
  detector_name           = aws_cloudwatch_log_group.ecs_log_group.name
  log_group_arn_list      = [aws_cloudwatch_log_group.ecs_log_group.arn]
  evaluation_frequency    = var.log_anomaly_detection.evaluation_frequency
  anomaly_visibility_time = var.log_anomaly_detection.anomaly_visibility_time
  filter_pattern          = var.log_anomaly_detection.filter_pattern != "" ? var.log_anomaly_detection.filter_pattern : null
  enabled                 = true
  tags                    = local.common_tags
}

resource "aws_alb_target_group" "target_group" {
  count                = var.application_load_balancer.enabled ? 1 : 0
  name                 = local.main_target_group_name
  port                 = var.application_load_balancer.container_port
  protocol             = var.application_load_balancer.protocol
  vpc_id               = var.vpc_id
  target_type          = local.target_group_target_type
  deregistration_delay = var.application_load_balancer.deregister_deregistration_delay

  dynamic "stickiness" {
    for_each = var.application_load_balancer.stickiness ? [1] : []
    content {
      cookie_duration = var.application_load_balancer.stickiness_ttl
      cookie_name     = var.application_load_balancer.cookie_name
      type            = var.application_load_balancer.stickiness_type
    }
  }

  health_check {
    healthy_threshold   = var.application_load_balancer.health_check_threshold_healthy
    interval            = var.application_load_balancer.health_check_interval_sec
    protocol            = var.application_load_balancer.health_check_protocol
    matcher             = var.application_load_balancer.health_check_protocol == "HTTP" ? var.application_load_balancer.health_check_matcher : null
    timeout             = var.application_load_balancer.health_check_timeout_sec
    path                = var.application_load_balancer.health_check_protocol == "HTTP" ? var.application_load_balancer.health_check_path : null
    unhealthy_threshold = var.application_load_balancer.health_check_threshold_unhealthy
    port                = var.application_load_balancer.health_check_port
  }

  depends_on = [aws_alb_target_group.target_group_additional]
  tags       = local.common_tags
}

resource "aws_alb_target_group" "target_group_additional" {
  for_each = {
    for idx, alb in var.additional_load_balancers : idx => alb
    if alb.enabled && try(alb.action_type, "forward") == "forward"
  }

  name                 = local.additional_target_group_names[each.key]
  port                 = each.value.container_port
  protocol             = each.value.protocol
  vpc_id               = var.vpc_id
  target_type          = local.target_group_target_type
  deregistration_delay = each.value.deregister_deregistration_delay

  dynamic "stickiness" {
    for_each = each.value.stickiness ? [1] : []
    content {
      cookie_duration = each.value.stickiness_ttl
      cookie_name     = each.value.cookie_name
      type            = each.value.stickiness_type
    }
  }

  health_check {
    healthy_threshold   = each.value.health_check_threshold_healthy
    interval            = each.value.health_check_interval_sec
    protocol            = each.value.health_check_protocol
    matcher             = each.value.health_check_protocol == "HTTP" ? each.value.health_check_matcher : null
    timeout             = each.value.health_check_timeout_sec
    path                = each.value.health_check_protocol == "HTTP" ? each.value.health_check_path : null
    unhealthy_threshold = each.value.health_check_threshold_unhealthy
    port                = each.value.health_check_port
  }

  tags = local.common_tags
}

########################
# Listener rules for ALB
#########################

resource "aws_lb_listener_rule" "rule" {
  count = var.application_load_balancer.enabled && var.application_load_balancer.protocol == "HTTP" ? 1 : 0

  listener_arn = var.application_load_balancer.listener_arn

  dynamic "action" {
    for_each = var.application_load_balancer.action_type == "forward" ? [1] : []
    content {
      type = "forward"

      forward {
        target_group {
          arn = aws_alb_target_group.target_group[0].arn
        }

        stickiness {
          enabled  = var.application_load_balancer.stickiness
          duration = var.application_load_balancer.stickiness_ttl
        }
      }
    }
  }

  dynamic "action" {
    for_each = var.application_load_balancer.action_type == "fixed-response" ? [1] : []
    content {
      type = "fixed-response"
      fixed_response {
        content_type = "text/plain"
        message_body = "Unauthorized"
        status_code  = "401"
      }
    }
  }

  dynamic "condition" {
    for_each = length(var.application_load_balancer.host) > 0 ? [1] : []
    content {
      host_header {
        values = [var.application_load_balancer.host]
      }
    }
  }

  dynamic "condition" {
    for_each = length(var.application_load_balancer.path) > 0 ? [1] : []
    content {
      path_pattern {
        values = [var.application_load_balancer.path]
      }
    }
  }

  depends_on = [aws_alb_target_group.target_group, aws_lb_listener_rule.rule_additional, aws_alb_target_group.target_group_additional]
  tags       = local.common_tags
}


resource "aws_lb_listener_rule" "rule_additional" {
  for_each = {
    for idx, alb in var.additional_load_balancers : idx => alb
    if alb.enabled && alb.protocol == "HTTP"
  }

  listener_arn = each.value.listener_arn

  dynamic "action" {
    for_each = each.value.action_type == "forward" ? [1] : []
    content {
      type = "forward"

      forward {
        target_group {
          arn = aws_alb_target_group.target_group_additional[each.key].arn
        }

        stickiness {
          enabled  = each.value.stickiness
          duration = each.value.stickiness_ttl
        }
      }
    }
  }

  dynamic "action" {
    for_each = each.value.action_type == "fixed-response" ? [1] : []
    content {
      type = "fixed-response"
      fixed_response {
        content_type = "text/plain"
        message_body = "Unauthorized"
        status_code  = "401"
      }
    }
  }

  dynamic "condition" {
    for_each = length(each.value.host) > 0 ? [1] : []
    content {
      host_header {
        values = [each.value.host]
      }
    }
  }

  dynamic "condition" {
    for_each = length(each.value.path) > 0 ? [1] : []
    content {
      path_pattern {
        values = [each.value.path]
      }
    }
  }

  depends_on = [aws_alb_target_group.target_group_additional]
  tags       = local.common_tags
}

########################
# Listeners for NLB
#########################

resource "aws_lb_listener" "tcp_listener" {
  count = var.application_load_balancer.enabled && var.application_load_balancer.protocol == "TCP" ? 1 : 0

  load_balancer_arn = var.application_load_balancer.nlb_arn
  port              = var.application_load_balancer.nlb_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.target_group[0].arn
  }

  tags = local.common_tags
}

resource "aws_lb_listener" "tcp_listener_additional" {
  for_each = {
    for idx, alb in var.additional_load_balancers : idx => alb
    if alb.enabled && alb.protocol == "TCP"
  }

  load_balancer_arn = each.value.nlb_arn
  port              = each.value.nlb_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.target_group_additional[each.key].arn
  }

  depends_on = [aws_alb_target_group.target_group_additional]
  tags       = local.common_tags
}

########################
# Initial Task Definition
#########################

resource "aws_ecs_task_definition" "task_definition" {
  family                   = "${data.aws_ecs_cluster.ecs_cluster.cluster_name}_${var.ecs_service_name}"
  network_mode             = var.network_mode
  requires_compatibilities = [var.ecs_launch_type]
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  task_role_arn            = local.task_role_arn
  execution_role_arn       = local.execution_role_arn
  container_definitions    = local.container_definitions_json
  tags                     = local.common_tags

  lifecycle {
    ignore_changes = all
  }
}

resource "aws_ecs_task_definition" "template" {
  count = var.task_definition_template.enabled ? 1 : 0

  family                   = "${data.aws_ecs_cluster.ecs_cluster.cluster_name}_${var.ecs_service_name}${var.task_definition_template.family_suffix}"
  network_mode             = var.network_mode
  requires_compatibilities = [var.ecs_launch_type]
  cpu                      = var.task_definition_template.cpu
  memory                   = var.task_definition_template.memory
  task_role_arn            = local.task_role_arn
  execution_role_arn       = local.execution_role_arn
  container_definitions    = jsonencode(local.tdt_container_definitions)
  tags                     = local.common_tags

  # EC2 tasks run on whatever the instance is, so the platform is only declared
  # for Fargate.
  dynamic "runtime_platform" {
    for_each = var.ecs_launch_type == "FARGATE" ? [1] : []
    content {
      cpu_architecture        = var.task_definition_template.cpu_architecture
      operating_system_family = var.task_definition_template.operating_system_family
    }
  }

  dynamic "ephemeral_storage" {
    for_each = var.task_definition_template.ephemeral_storage_gib != null ? [1] : []
    content {
      size_in_gib = var.task_definition_template.ephemeral_storage_gib
    }
  }

  dynamic "volume" {
    for_each = local.tdt_volumes
    content {
      name      = volume.value.name
      host_path = volume.value.host_path

      dynamic "efs_volume_configuration" {
        for_each = volume.value.efs_volume_configuration != null ? [volume.value.efs_volume_configuration] : []
        content {
          file_system_id          = efs_volume_configuration.value.file_system_id
          root_directory          = efs_volume_configuration.value.root_directory
          transit_encryption      = efs_volume_configuration.value.transit_encryption
          transit_encryption_port = efs_volume_configuration.value.transit_encryption_port

          dynamic "authorization_config" {
            for_each = efs_volume_configuration.value.authorization_config != null ? [efs_volume_configuration.value.authorization_config] : []
            content {
              access_point_id = authorization_config.value.access_point_id
              iam             = authorization_config.value.iam
            }
          }
        }
      }
    }
  }

  # Every change replaces the revision. Registering the new one before the old
  # is deregistered means the family always has an ACTIVE revision for a
  # deploy that reads it mid-apply.
  lifecycle {
    create_before_destroy = true

    precondition {
      condition     = length(distinct(local.tdt_container_names)) == length(local.tdt_container_names)
      error_message = "task_definition_template: container names must be unique across the application container, the generated init, fluent-bit and otel-collector containers, sidecars (and their <name>-secret-init containers) and container_definitions, and every container in container_definitions needs a name."
    }

    precondition {
      condition     = alltrue([for name in keys(var.task_definition_template.container_overrides) : contains(local.tdt_generated_containers[*].name, name)])
      error_message = "task_definition_template.container_overrides: every key must name a generated container (${join(", ", local.tdt_generated_containers[*].name)})."
    }

    precondition {
      condition     = length(distinct(local.tdt_port_mapping_names)) == length(local.tdt_port_mapping_names)
      error_message = "task_definition_template: port mapping names must be unique across the task: the application's \"default\" and additional_ports, otel-collector-4317-tcp and otel-collector-4318-tcp, and each sidecar's <name>-<port>-tcp and additional_ports."
    }

    precondition {
      condition     = length(distinct(local.tdt_volumes[*].name)) == length(local.tdt_volumes)
      error_message = "task_definition_template: volume names must be unique across the generated volumes (shared-volume, writable-*, <sidecar>-secrets, <sidecar>-writable-*) and volumes."
    }

    precondition {
      condition     = alltrue([for v in local.tdt_volumes : can(regex("^[a-zA-Z0-9][a-zA-Z0-9_-]{0,254}$", v.name))])
      error_message = "task_definition_template: volume names must start with a letter or digit and contain only letters, digits, hyphens and underscores. A writable_dirs path becomes a volume name with its slashes turned into hyphens, so it cannot contain other characters such as dots. Invalid: ${join(", ", [for v in local.tdt_volumes : v.name if !can(regex("^[a-zA-Z0-9][a-zA-Z0-9_-]{0,254}$", v.name))])}."
    }

    precondition {
      condition     = !contains(["awsvpc", "host"], var.network_mode) || length(local.tdt_duplicate_container_ports) == 0
      error_message = "task_definition_template: with network_mode \"${var.network_mode}\" every container shares one network namespace, so two containers cannot use the same container port. Used by more than one container: ${join(", ", local.tdt_duplicate_container_ports)}."
    }

    precondition {
      condition     = length(local.tdt_missing_lb_ports) == 0
      error_message = "task_definition_template: the service's load balancers forward to container port(s) ${join(", ", local.tdt_missing_lb_ports)} of ${var.container_name}, which the template does not map. Set task_definition_template.port or an additional_ports entry to each load balancer's container_port."
    }

    precondition {
      condition     = length(local.tdt_missing_service_connect_ports) == 0
      error_message = "task_definition_template: Service Connect (client-server) advertises port mapping(s) ${join(", ", local.tdt_missing_service_connect_ports)} of ${var.container_name}, which the template does not have. \"default\" is task_definition_template.port; each service_connect.additional_ports name must be a key of task_definition_template.additional_ports."
    }

    precondition {
      condition     = !local.tdt_service_connect_server || local.tdt_app_default_protocol == null ? true : (local.tdt_app_default_protocol == "tcp") == (var.service_connect.appProtocol == "tcp")
      error_message = "task_definition_template: service_connect.appProtocol is \"${var.service_connect.appProtocol}\" but the template's default port mapping has app_protocol \"${coalesce(local.tdt_app_default_protocol, "none")}\". Use app_protocol = \"tcp\" with a tcp Service Connect service, and http, http2 or grpc with an http one."
    }
  }
}

resource "aws_ecs_service" "ecs_service" {
  name                               = var.ecs_service_name
  cluster                            = data.aws_ecs_cluster.ecs_cluster.id
  task_definition                    = aws_ecs_task_definition.task_definition.arn
  desired_count                      = var.desired_count
  deployment_minimum_healthy_percent = var.deployment.min_healthy_percent
  deployment_maximum_percent         = var.deployment.max_healthy_percent

  enable_execute_command = var.enable_execute_command
  launch_type            = var.capacity_provider_strategy == "" ? var.ecs_launch_type : null
  scheduling_strategy    = "REPLICA"
  propagate_tags         = "SERVICE"
  platform_version       = var.ecs_launch_type == "FARGATE" ? "LATEST" : null
  deployment_controller {
    type = "ECS"
  }

  deployment_circuit_breaker {
    enable   = var.deployment.circuit_breaker_enabled
    rollback = var.deployment.rollback_enabled
  }

  dynamic "network_configuration" {
    for_each = var.network_mode == "awsvpc" ? [1] : []
    content {
      security_groups  = var.security_group_ids
      subnets          = var.subnet_ids
      assign_public_ip = var.assign_public_ip
    }
  }

  dynamic "alarms" {
    for_each = var.deployment.cloudwatch_alarm_enabled ? [1] : []
    content {
      alarm_names = var.deployment.cloudwatch_alarm_names
      enable      = true
      rollback    = var.deployment.cloudwatch_alarm_rollback
    }
  }

  dynamic "load_balancer" {
    for_each = var.application_load_balancer.enabled && var.application_load_balancer.action_type == "forward" ? [1] : []
    content {
      target_group_arn = aws_alb_target_group.target_group[0].arn
      container_name   = var.container_name
      container_port   = var.application_load_balancer.container_port
    }
  }

  dynamic "capacity_provider_strategy" {
    for_each = var.capacity_provider_strategy != "" ? [1] : []
    content {
      capacity_provider = var.capacity_provider_strategy
      weight            = 1
      base              = 0
    }
  }

  dynamic "ordered_placement_strategy" {
    for_each = var.placement_strategy
    content {
      type  = ordered_placement_strategy.value.type
      field = ordered_placement_strategy.value.field
    }
  }

  dynamic "placement_constraints" {
    for_each = var.placement_constraints
    content {
      type       = placement_constraints.value.type
      expression = placement_constraints.value.expression
    }
  }

  dynamic "load_balancer" {
    for_each = {
      for idx, alb in var.additional_load_balancers : idx => alb
      if alb.enabled && alb.action_type == "forward"
    }
    content {
      target_group_arn = aws_alb_target_group.target_group_additional[load_balancer.key].arn
      container_name   = var.container_name
      container_port   = load_balancer.value.container_port
    }
  }

  dynamic "service_connect_configuration" {
    for_each = var.service_connect.enabled ? [1] : []
    content {
      enabled   = true
      namespace = var.ecs_cluster_name

      dynamic "service" {
        for_each = contains(["client-server"], var.service_connect.type) ? [1] : []
        content {
          port_name      = "default"
          discovery_name = var.service_connect.name
          client_alias {
            port     = var.service_connect.port
            dns_name = var.service_connect.name
          }
          timeout {
            idle_timeout_seconds        = var.service_connect.appProtocol == "http" ? 0 : null
            per_request_timeout_seconds = var.service_connect.appProtocol == "http" ? var.service_connect.timeout : null
          }
        }
      }

      dynamic "service" {
        for_each = var.service_connect.type == "client-server" && length(var.service_connect.additional_ports) > 0 ? var.service_connect.additional_ports : []
        content {
          port_name      = service.value.name
          discovery_name = "${var.service_connect.name}-${service.value.name}"
          client_alias {
            port     = service.value.port
            dns_name = var.service_connect.name
          }
          timeout {
            idle_timeout_seconds        = 0
            per_request_timeout_seconds = var.service_connect.timeout
          }
        }
      }
    }
  }

  tags = local.common_tags

  lifecycle {
    ignore_changes = [task_definition, platform_version, desired_count, service_connect_configuration.0.namespace]
  }

  depends_on = [
    aws_lb_listener_rule.rule,
    aws_lb_listener_rule.rule_additional,
    aws_alb_target_group.target_group,
    aws_alb_target_group.target_group_additional,
    aws_ecs_task_definition.task_definition
  ]
}

###############################################################################
# SQS AUTO SCALING - SCALE OUT POLICY (Proportional Step Ladder)
###############################################################################
###############################################################################
# SQS AUTO SCALING - SCALE IN POLICY (Conservative single step)
###############################################################################
###############################################################################
# SQS AUTO SCALING - SCALE OUT ALARM (Age-based, fast detection)
###############################################################################
###############################################################################
# SQS AUTO SCALING - SCALE OUT ALARM with SMA (Age-based, smoothed)
###############################################################################
###############################################################################
# SQS AUTO SCALING - SCALE IN READINESS ALARM (Age-based, conservative)
###############################################################################
###############################################################################
# SQS AUTO SCALING - QUEUE EMPTY CHECKS (for safe scale-in)
###############################################################################
###############################################################################
# SQS AUTO SCALING - COMPOSITE SCALE-IN SAFETY ALARM
###############################################################################
###############################################################################
# ECR REPOSITORY
###############################################################################
module "ecr" {
  count   = var.ecr.create_repo ? 1 : 0
  source  = "terraform-aws-modules/ecr/aws"
  version = "2.3.0"

  repository_name                 = var.ecr.repo_name != "" ? var.ecr.repo_name : var.ecs_service_name
  repository_image_tag_mutability = var.ecr.mutability
  repository_image_scan_on_push   = var.ecr.scan_on_push
  repository_encryption_type      = var.ecr.kms_key_id != "" ? "KMS" : null
  repository_kms_key              = var.ecr.kms_key_id != "" ? var.ecr.kms_key_id : null
  attach_repository_policy        = false
  repository_lifecycle_policy = jsonencode({
    rules = concat(
      [
        {
          rulePriority = 1,
          description  = "Protect ${join(", ", var.ecr.protected_prefixes)} branches tags",
          selection = {
            tagStatus     = "tagged",
            tagPrefixList = var.ecr.protected_prefixes,
            countType     = "imageCountMoreThan",
            countNumber   = var.ecr.protected_retention
          },
          action = {
            type = "expire"
          }
        }
      ],
      [
        for idx, prefix in var.ecr.versioned_prefixes : {
          rulePriority = idx + 2, # Dynamic priority starting from 2
          description  = "Keep number of latest releases images for ${prefix}",
          selection = {
            tagStatus     = "tagged",
            tagPrefixList = [prefix],
            countType     = "imageCountMoreThan",
            countNumber   = var.ecr.versioned_retention
          },
          action = {
            type = "expire"
          }
        }
      ],
      [
        {
          rulePriority = length(var.ecr.versioned_prefixes) + 2,
          description  = "Expire all tagged images older than ${var.ecr.tagged_ttl_days} days",
          selection = {
            tagStatus      = "tagged",
            tagPatternList = ["*"],
            countType      = "sinceImagePushed",
            countUnit      = "days",
            countNumber    = var.ecr.tagged_ttl_days
          },
          action = {
            type = "expire"
          }
        },
        {
          rulePriority = length(var.ecr.versioned_prefixes) + 3,
          description  = "Remove untagged images older than ${var.ecr.untagged_ttl_days} days",
          selection = {
            tagStatus   = "untagged",
            countType   = "sinceImagePushed",
            countUnit   = "days",
            countNumber = var.ecr.untagged_ttl_days
          },
          action = {
            type = "expire"
          }
        }
      ]
    )
  })
  tags = local.common_tags
}

###############################################################################
# ROUTE 53 RECORDS
###############################################################################

# Route 53 record for main ALB
resource "aws_route53_record" "main_alb_record" {
  count   = local.create_main_route53_record ? 1 : 0
  zone_id = var.application_load_balancer.route_53_host_zone_id
  name    = var.application_load_balancer.host
  type    = "A"

  alias {
    name                   = data.aws_lb.main_alb[0].dns_name
    zone_id                = data.aws_lb.main_alb[0].zone_id
    evaluate_target_health = true
  }
}

# Route 53 records for additional ALBs
resource "aws_route53_record" "additional_alb_records" {
  for_each = {
    for idx, alb in var.additional_load_balancers : idx => alb
    if alb.enabled && alb.route_53_host_zone_id != "" && alb.host != "" && local.additional_lb_arns[idx] != ""
  }

  zone_id = each.value.route_53_host_zone_id
  name    = each.value.host
  type    = "A"

  alias {
    name                   = data.aws_lb.additional_albs[each.key].dns_name
    zone_id                = data.aws_lb.additional_albs[each.key].zone_id
    evaluate_target_health = true
  }
}