data "aws_ecs_cluster" "ecs_cluster" {
  cluster_name = var.ecs_cluster_name
}

resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name              = "/ecs/${data.aws_ecs_cluster.ecs_cluster.cluster_name}/${var.ecs_service_name}"
  retention_in_days = var.log_retention_days
}

# Convert to for_each to create multiple target groups
resource "aws_alb_target_group" "target_group" {
  for_each    = { for tg in var.target_groups : tg.name => tg }
  name        = each.key
  port        = each.value.port
  protocol    = each.value.protocol
  vpc_id      = var.vpc_id
  target_type = each.value.target_type

  health_check {
    healthy_threshold   = lookup(each.value, "health_check_threshold_healthy", var.health_check_threshold_healthy)
    interval            = lookup(each.value, "health_check_interval_sec", var.health_check_interval_sec)
    protocol            = lookup(each.value, "health_check_protocol", var.health_check_protocol)
    matcher             = lookup(each.value, "health_check_protocol", var.health_check_protocol) == "HTTP" ? lookup(each.value, "health_check_matcher", var.health_check_matcher) : ""
    timeout             = lookup(each.value, "health_check_timeout_sec", var.health_check_timeout_sec)
    path                = lookup(each.value, "health_check_protocol", var.health_check_protocol) == "HTTP" ? lookup(each.value, "health_check_path", var.health_check_path) : null
    unhealthy_threshold = lookup(each.value, "health_check_threshold_unhealthy", var.health_check_threshold_unhealthy)
  }
}

# Modified rules routing to reference specific target groups
resource "aws_lb_listener_rule" "rule" {
  for_each = { for idx, rule in var.rules_routing : idx => rule }

  listener_arn = var.lb_listener_arn
  priority     = each.value.priority

  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.target_group[each.value.target_group_name].arn
  }

  condition {
    host_header {
      values = lookup(each.value, "host", null) != null ? [each.value.host] : []
    }
    path_pattern {
      values = lookup(each.value, "path", null) != null ? [each.value.path] : []
    }
  }
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
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]
    }
  ])
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }
  lifecycle {
    ignore_changes = [container_definitions, family, memory, cpu, requires_compatibilities, network_mode, runtime_platform]
  }
}

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

  # Modified to support multiple target groups
  dynamic "load_balancer" {
    for_each = length(var.target_groups) > 0 ? var.service_target_groups : []
    content {
      target_group_arn = aws_alb_target_group.target_group[load_balancer.value.target_group_name].arn
      container_name   = var.container_name
      container_port   = lookup(load_balancer.value, "container_port", var.container_port)
    }
  }

  lifecycle {
    ignore_changes = [task_definition]
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

resource "aws_cloudwatch_metric_alarm" "in_auto_scaling" {
  count               = var.scale_on_alarm_usage ? 1 : 0
  alarm_name          = "${var.ecs_cluster_name}/${var.ecs_service_name}/in-auto-scaling"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  threshold           = var.queue_scale_in_threshold
  alarm_description   = "Alarm when SQS backlog per instance"
  alarm_actions       = [aws_appautoscaling_policy.scale_in_by_alarm_policy[0].arn]
  treat_missing_data  = "breaching"
  metric_query {
    id          = "proportion"
    expression  = "(FILL(m1,0))/FILL(m2,1)"
    label       = "proportion"
    return_data = true
  }
  metric_query {
    id          = "m1"
    label       = "Queue Size (Messages in SQS)"
    return_data = false
    metric {
      namespace   = "AWS/SQS"
      metric_name = "ApproximateNumberOfMessagesVisible"
      period      = 60
      stat        = "Sum"
      dimensions = {
        QueueName = var.queue_name
      }
    }
  }

  metric_query {
    id          = "m2"
    label       = "Number of InService Instances"
    return_data = false
    metric {
      namespace   = "ECS/ContainerInsights"
      metric_name = "DesiredTaskCount"
      period      = 60
      stat        = "Average"
      dimensions = {
        ServiceName = var.ecs_service_name
        ClusterName = var.ecs_cluster_name
      }
    }
  }
  depends_on = [aws_ecs_service.ecs_service]
}

resource "aws_cloudwatch_metric_alarm" "out_auto_scaling" {
  count               = var.scale_on_alarm_usage ? 1 : 0
  alarm_name          = "${var.ecs_cluster_name}/${var.ecs_service_name}/out-auto-scaling"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = var.queue_scale_out_threshold
  alarm_description   = "Alarm when SQS backlog per instance"
  alarm_actions       = [aws_appautoscaling_policy.scale_out_by_alarm_policy[0].arn]
  treat_missing_data  = "breaching"
  metric_query {
    id          = "proportion"
    expression  = "(FILL(m2,0))/FILL(m1,1)"
    label       = "proportion"
    return_data = true
  }
  metric_query {
    id          = "m1"
    label       = "Queue Size (Messages in SQS)"
    return_data = false
    metric {
      namespace   = "AWS/SQS"
      metric_name = "ApproximateNumberOfMessagesVisible"
      period      = 60
      stat        = "Sum"
      dimensions = {
        QueueName = var.queue_name
      }
    }
  }

  metric_query {
    id          = "m2"
    label       = "Number of InService Instances"
    return_data = false
    metric {
      namespace   = "ECS/ContainerInsights"
      metric_name = "DesiredTaskCount"
      period      = 60
      stat        = "Average"
      dimensions = {
        ServiceName = var.ecs_service_name
        ClusterName = var.ecs_cluster_name
      }
    }
  }
  depends_on = [aws_ecs_service.ecs_service]
}
