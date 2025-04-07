data "aws_ecs_cluster" "ecs_cluster" {
  cluster_name = var.ecs_cluster_name
}

data "external" "listener_rules" {
  count = var.application_load_balancer != {} && var.application_load_balancer.listener_arn != "" ? 1 : 0

  program = ["bash", "-c", <<EOT
    aws elbv2 describe-rules --listener-arn ${var.application_load_balancer.listener_arn} | \
    jq -c '{priorities: ([.Rules[].Priority | select(. != "default") | tostring] | join(","))}'
  EOT
  ]
}

locals {
  existing_priorities_string = var.application_load_balancer != {} && var.application_load_balancer.listener_arn != "" ? try(data.external.listener_rules[0].result.priorities, "") : ""
  existing_priorities        = local.existing_priorities_string != "" ? split(",", local.existing_priorities_string) : []

  max_priority  = length(local.existing_priorities) > 0 ? max(local.existing_priorities...) : 0
  next_priority = local.max_priority + 1
}

resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name              = "/ecs/${data.aws_ecs_cluster.ecs_cluster.cluster_name}/${var.ecs_service_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_alb_target_group" "target_group" {
  count       = var.application_load_balancer != {} && var.application_load_balancer.listener_arn != "" ? 1 : 0
  name        = replace("${data.aws_ecs_cluster.ecs_cluster.cluster_name}-${var.ecs_service_name}-tg", "_", "-")
  port        = var.application_load_balancer.container_port
  protocol    = var.application_load_balancer.protocol
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    healthy_threshold   = var.application_load_balancer.health_check_threshold_healthy
    interval            = var.application_load_balancer.health_check_interval_sec
    protocol            = var.application_load_balancer.health_check_protocol
    matcher             = var.application_load_balancer.health_check_matcher
    timeout             = var.application_load_balancer.health_check_timeout_sec
    path                = var.application_load_balancer.health_check_path
    unhealthy_threshold = var.application_load_balancer.health_check_threshold_unhealthy
  }
}

resource "aws_lb_listener_rule" "rule" {
  count        = var.application_load_balancer != {} && var.application_load_balancer.listener_arn != "" ? 1 : 0
  listener_arn = var.application_load_balancer.listener_arn
  priority     = local.next_priority

  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.target_group[0].arn
  }
  lifecycle {
    ignore_changes = [priority]
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
  depends_on = [aws_alb_target_group.target_group]
}

resource "aws_ecs_task_definition" "task_definition" {
  family                   = "${data.aws_ecs_cluster.ecs_cluster.cluster_name}_${var.ecs_service_name}"
  network_mode             = "awsvpc"
  requires_compatibilities = [var.ecs_launch_type]
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  container_definitions = jsonencode([
    {
      name      = var.container_name
      image     = var.container_image
      essential = true

      portMappings = [
        {
          containerPort = var.application_load_balancer != {} ? var.application_load_balancer.container_port : 80
          hostPort      = var.application_load_balancer != {} ? var.application_load_balancer.container_port : 80
          protocol      = "tcp"
          name          = "${data.aws_ecs_cluster.ecs_cluster.cluster_name}_${var.ecs_service_name}"
          appProtocol   = "http"
        }
      ]
    }
  ])
  lifecycle {
    ignore_changes = all
  }
}

data "aws_region" "current" {}

resource "aws_ecs_service" "ecs_service" {
  name                               = var.ecs_service_name
  cluster                            = data.aws_ecs_cluster.ecs_cluster.id
  task_definition                    = aws_ecs_task_definition.task_definition.arn
  desired_count                      = var.ecs_task_count
  deployment_minimum_healthy_percent = var.deployment_min_healthy
  deployment_maximum_percent         = var.deployment_max_percent

  enable_execute_command = false
  launch_type            = var.ecs_launch_type
  scheduling_strategy    = "REPLICA"
  propagate_tags         = "NONE"
  platform_version       = "LATEST"

  deployment_controller {
    type = "ECS"
  }

  deployment_circuit_breaker {
    enable   = var.deployment_circuit_breaker
    rollback = var.deployment_rollback
  }

  network_configuration {
    security_groups  = var.security_group_ids
    subnets          = var.subnet_ids
    assign_public_ip = var.assign_public_ip
  }

  dynamic "alarms" {
    for_each = var.deployment_cloudwatch_alarm_enabled ? [1] : []
    content {
      alarm_names = var.deployment_cloudwatch_alarm_names
      enable      = true
      rollback    = var.deployment_cloudwatch_alarm_rollback
    }
  }

  dynamic "load_balancer" {
    for_each = var.application_load_balancer != {} && var.application_load_balancer.listener_arn != "" ? [1] : []
    content {
      target_group_arn = aws_alb_target_group.target_group[0].arn
      container_name   = var.container_name
      container_port   = var.application_load_balancer.container_port
    }
  }


  dynamic "service_connect_configuration" {
    for_each = var.service_connect_enabled ? [1] : []
    content {
      namespace = var.ecs_cluster_name
      enabled   = true
      service {
        port_name = "${var.ecs_cluster_name}_${var.ecs_service_name}"
      }
    }

  }

  lifecycle {
    ignore_changes = concat(
      ["task_definition", "platform_version"],
      var.enable_autoscaling ? ["desired_count"] : []
    )
  }

  depends_on = [aws_lb_listener_rule.rule]
}

resource "aws_appautoscaling_target" "ecs_target" {
  count              = var.enable_autoscaling ? 1 : 0
  min_capacity       = var.min_task_count
  max_capacity       = var.max_task_count
  resource_id        = "service/${var.ecs_cluster_name}/${var.ecs_service_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
  depends_on         = [aws_ecs_service.ecs_service]
}

resource "aws_appautoscaling_policy" "scale_by_cpu_policy" {
  count              = var.scale_on_cpu_usage ? 1 : 0
  name               = "${var.ecs_cluster_name}/${var.ecs_service_name}/scale-by-cpu-policy"
  service_namespace  = "ecs"
  resource_id        = "service/${var.ecs_cluster_name}/${var.ecs_service_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  policy_type        = "TargetTrackingScaling"
  target_tracking_scaling_policy_configuration {
    disable_scale_in   = false
    scale_in_cooldown  = var.scale_cooldown_in_sec
    scale_out_cooldown = var.scale_cooldown_out_sec
    target_value       = var.scale_on_cpu_target

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
  depends_on = [aws_ecs_service.ecs_service, aws_appautoscaling_target.ecs_target]
}

resource "aws_appautoscaling_policy" "scale_by_memory_policy" {
  count              = var.scale_on_memory_usage ? 1 : 0
  name               = "${var.ecs_cluster_name}/${var.ecs_service_name}/scale-by-memory-policy"
  service_namespace  = "ecs"
  resource_id        = "service/${var.ecs_cluster_name}/${var.ecs_service_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  policy_type        = "TargetTrackingScaling"
  target_tracking_scaling_policy_configuration {
    disable_scale_in   = false
    scale_in_cooldown  = var.scale_cooldown_in_sec
    scale_out_cooldown = var.scale_cooldown_out_sec
    target_value       = var.scale_on_memory_target

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
  }
  depends_on = [aws_ecs_service.ecs_service, aws_appautoscaling_target.ecs_target]
}

resource "aws_appautoscaling_policy" "scale_out_by_alarm_policy" {
  count              = var.scale_on_alarm_usage ? 1 : 0
  name               = "${var.ecs_cluster_name}/${var.ecs_service_name}/scale-out-by-alarm-policy"
  service_namespace  = "ecs"
  resource_id        = "service/${var.ecs_cluster_name}/${var.ecs_service_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  policy_type        = "StepScaling"
  step_scaling_policy_configuration {
    adjustment_type          = "ChangeInCapacity"
    cooldown                 = var.scale_cooldown_out_sec
    metric_aggregation_type  = "Average"
    min_adjustment_magnitude = 0

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = var.scale_by_alarm_out_adjustment
    }
  }
  depends_on = [aws_ecs_service.ecs_service, aws_appautoscaling_target.ecs_target]
}

resource "aws_appautoscaling_policy" "scale_in_by_alarm_policy" {
  count              = var.scale_on_alarm_usage ? 1 : 0
  name               = "${var.ecs_cluster_name}/${var.ecs_service_name}/scale-in-by-alarm-policy"
  service_namespace  = "ecs"
  resource_id        = "service/${var.ecs_cluster_name}/${var.ecs_service_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  policy_type        = "StepScaling"

  step_scaling_policy_configuration {
    adjustment_type          = "ChangeInCapacity"
    cooldown                 = var.scale_cooldown_in_sec
    metric_aggregation_type  = "Average"
    min_adjustment_magnitude = 0

    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = var.scale_by_alarm_in_adjustment
    }
  }
  depends_on = [aws_ecs_service.ecs_service, aws_appautoscaling_target.ecs_target]
}

###############################################################################
# SCALE OUT ALARM
###############################################################################
resource "aws_cloudwatch_metric_alarm" "out_auto_scaling" {
  count               = var.scale_on_alarm_usage ? 1 : 0
  alarm_name          = "${var.ecs_cluster_name}/${var.ecs_service_name}/out-auto-scaling"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = var.queue_scale_out_threshold  # e.g., 50
  alarm_description   = "Scale OUT if SQS backlog exceeds threshold"
  datapoints_to_alarm = 1
  alarm_actions       = [aws_appautoscaling_policy.scale_out_by_alarm_policy[0].arn]
  treat_missing_data  = "breaching"

  # Remove the old metric_query blocks. Instead, do a direct reference to SQS backlog:
  namespace   = "AWS/SQS"
  metric_name = "ApproximateNumberOfMessagesVisible"
  period      = 60
  statistic   = "Average"
  dimensions = {
    QueueName = var.queue_name
  }

  depends_on = [aws_ecs_service.ecs_service]
}

###############################################################################
# SCALE IN ALARM
###############################################################################
resource "aws_cloudwatch_metric_alarm" "in_auto_scaling" {
  count               = var.scale_on_alarm_usage ? 1 : 0
  alarm_name          = "${var.ecs_cluster_name}/${var.ecs_service_name}/in-auto-scaling"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  threshold           = var.queue_scale_in_threshold  # e.g., 10
  alarm_description   = "Scale IN if SQS backlog drops below threshold"
  datapoints_to_alarm = 1
  alarm_actions       = [aws_appautoscaling_policy.scale_in_by_alarm_policy[0].arn]
  treat_missing_data  = "breaching"

  # Again, just reference the SQS metric directly
  namespace   = "AWS/SQS"
  metric_name = "ApproximateNumberOfMessagesVisible"
  period      = 60
  statistic   = "Average"
  dimensions = {
    QueueName = var.queue_name
  }

  depends_on = [aws_ecs_service.ecs_service]
}
