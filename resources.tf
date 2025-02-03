data "aws_ecs_cluster" "ecs_cluster" {
  cluster_name = var.cluster_name
}

resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name              = "/ecs/${data.aws_ecs_cluster.ecs_cluster.cluster_name}/${var.service_name}"
  retention_in_days = 30
}

resource "aws_lb_listener_rule" "host_rule" {
  for_each = { for idx, rule in var.host_rules : idx => rule }

  listener_arn = var.listener_arn
  priority     = each.value.priority

  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.target_group[0].arn
  }

  condition {
    host_header {
      values = [each.value.value]
    }
  }
}
resource "aws_lb_listener_rule" "path_rule" {
  for_each = { for idx, rule in var.path_rules : idx => rule }

  listener_arn = var.listener_arn
  priority     = each.value.priority

  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.target_group[0].arn
  }

  condition {
    path_pattern {
      values = [each.value.value]
    }
  }
}

resource "aws_alb_target_group" "target_group" {
  count       = var.enable_target_group ? 1 : 0
  name        = var.target_group_name
  port        = var.target_group_port
  protocol    = var.target_group_protocol
  vpc_id      = var.vpc_id
  target_type = var.target_type

  health_check {
    healthy_threshold   = var.health_check_healthy_threshold
    interval            = var.health_check_interval
    protocol            = var.health_check_protocol
    matcher             = var.health_check_protocol == "HTTP" ? var.health_check_matcher : ""
    timeout             = var.health_check_timeout
    path                = var.health_check_protocol == "HTTP" ? var.health_check_path : null
    unhealthy_threshold = var.health_check_unhealthy_threshold
  }
}

resource "aws_ecs_task_definition" "task_definition" {
  family                   = "${data.aws_ecs_cluster.ecs_cluster.cluster_name}_${var.service_name}"
  network_mode             = "awsvpc"
  requires_compatibilities = [var.launch_type]
  cpu                      = 1024
  memory                   = 2048
  execution_role_arn       = var.execution_role_arn
  container_definitions = jsonencode([
    {
      name      = var.container_name
      image     = var.container_image
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.host_port
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
    ignore_changes = [container_definitions]
  }
}

resource "aws_ecs_service" "ecs_service" {
  name                               = var.service_name
  cluster                            = data.aws_ecs_cluster.ecs_cluster.id
  task_definition                    = aws_ecs_task_definition.task_definition.arn
  desired_count                      = var.desired_count
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  deployment_maximum_percent         = var.deployment_maximum_percent

  enable_execute_command = false
  launch_type            = var.launch_type
  scheduling_strategy    = "REPLICA"
  propagate_tags         = "NONE"
  platform_version       = "LATEST"
  deployment_controller {
    type = "ECS"
  }
  deployment_circuit_breaker {
    enable   = var.deployment_circuit_breaker_enabled
    rollback = var.deployment_circuit_breaker_rollback_enabled
  }
  network_configuration {
    security_groups  = var.security_groups
    subnets          = var.subnets
    assign_public_ip = var.assign_public_ip
  }
  dynamic "alarms" {
    for_each = var.deployment_cloudwatch_alarm_enabled ? [1] : []
    content {
      alarm_names = var.deployment_cloudwatch_alarm_names
      enable      = true
      rollback    = var.deployment_cloudwatch_alarm_rollback_enabled
    }

  }
  dynamic "load_balancer" {
    for_each = var.enable_target_group ? [1] : []
    content {
      target_group_arn = aws_alb_target_group.target_group[0].arn
      container_name   = var.container_name
      container_port   = var.container_port
    }
  }

  lifecycle {
    ignore_changes = [task_definition]
  }

  depends_on = [aws_lb_listener_rule.host_rule]

}

resource "aws_appautoscaling_target" "ecs_target" {
  count              = var.scaling_enabled ? 1 : 0
  min_capacity       = var.min_capacity
  max_capacity       = var.max_capacity
  resource_id        = "service/${var.cluster_name}/${var.service_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
  depends_on = [aws_ecs_service.ecs_service]
}

resource "aws_appautoscaling_policy" "scale_by_cpu_policy" {
  count              = var.scale_by_cpu_enabled ? 1 : 0
  name               = "${var.cluster_name}/${var.service_name}/scale-by-cpu-policy"
  service_namespace  = "ecs"
  resource_id        = "service/${var.cluster_name}/${var.service_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  policy_type        = "TargetTrackingScaling"
  target_tracking_scaling_policy_configuration {
    disable_scale_in   = false
    scale_in_cooldown  = var.scale_by_cpu_in_cooldown
    scale_out_cooldown = var.scale_by_cpu_out_cooldown
    target_value       = var.scale_by_cpu_target_value

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
  depends_on = [aws_ecs_service.ecs_service, aws_appautoscaling_target.ecs_target]
}
resource "aws_appautoscaling_policy" "scale_by_memory_policy" {
  count              = var.scale_by_memory_enabled ? 1 : 0
  name               = "${var.cluster_name}/${var.service_name}/scale-by-memory-policy"
  service_namespace  = "ecs"
  resource_id        = "service/${var.cluster_name}/${var.service_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  policy_type        = "TargetTrackingScaling"
  target_tracking_scaling_policy_configuration {
    disable_scale_in   = false
    scale_in_cooldown  = var.scale_by_memory_in_cooldown
    scale_out_cooldown = var.scale_by_memory_out_cooldown
    target_value       = var.scale_by_memory_target_value

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
  }
  depends_on = [aws_ecs_service.ecs_service, aws_appautoscaling_target.ecs_target]
}

resource "aws_appautoscaling_policy" "scale_out_by_alarm_policy" {
  count              = var.scale_by_alarm_enabled ? 1 : 0
  name               = "${var.cluster_name}/${var.service_name}/scale-out-by-alarm-policy"
  service_namespace  = "ecs"
  resource_id        = "service/${var.cluster_name}/${var.service_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  policy_type        = "StepScaling"
  step_scaling_policy_configuration {
    adjustment_type          = "ChangeInCapacity"
    cooldown                 = var.scale_by_alarm_out_cooldown
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
  count              = var.scale_by_alarm_enabled ? 1 : 0
  name               = "${var.cluster_name}/${var.service_name}/scale-in-by-alarm-policy"
  service_namespace  = "ecs"
  resource_id        = "service/${var.cluster_name}/${var.service_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  policy_type        = "StepScaling"

  step_scaling_policy_configuration {
    adjustment_type          = "ChangeInCapacity"
    cooldown                 = var.scale_by_alarm_in_cooldown
    metric_aggregation_type  = "Average"
    min_adjustment_magnitude = 0


    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = var.scale_by_alarm_in_adjustment
    }
  }
  depends_on = [aws_ecs_service.ecs_service, aws_appautoscaling_target.ecs_target]
}

###################
resource "aws_cloudwatch_metric_alarm" "in_auto_scaling" {
  count               = var.scale_by_alarm_enabled ? 1 : 0
  alarm_name          = "${var.cluster_name}/${var.service_name}/in-auto-scaling"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  threshold           = var.scale_by_alarm_in_threshold
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
        ServiceName = var.service_name
        ClusterName = var.cluster_name
      }
    }
  }
    depends_on = [aws_ecs_service.ecs_service]
}

resource "aws_cloudwatch_metric_alarm" "out_auto_scaling" {
  count               = var.scale_by_alarm_enabled ? 1 : 0
  alarm_name          = "${var.cluster_name}/${var.service_name}/out-auto-scaling"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = var.scale_by_alarm_out_threshold
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
        ServiceName = var.service_name
        ClusterName = var.cluster_name
      }
    }
  }
    depends_on = [aws_ecs_service.ecs_service]
}


