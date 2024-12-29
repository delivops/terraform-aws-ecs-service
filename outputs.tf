output "ecs_service_name" {
  value = aws_ecs_service.ecs_service.name
}

output "ecs_task_definition_arn" {
  value = aws_ecs_task_definition.task_definition.arn
}

output "target_group_arn" {
  value = var.enable_target_group ? aws_alb_target_group.target_group[0].arn : null
}

output "cloudwatch_log_group_name" {
  value = aws_cloudwatch_log_group.ecs_log_group.name
}
