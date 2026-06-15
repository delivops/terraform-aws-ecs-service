output "ecs_service_name" {
  value = aws_ecs_service.ecs_service.name
}
output "ecs_task_definition_arn" {
  value = aws_ecs_task_definition.task_definition.arn
}

output "cloudwatch_log_group_name" {
  value = aws_cloudwatch_log_group.ecs_log_group.name
}

output "route53_records" {
  description = "Route53 DNS records created"
  value = {
    main_record = var.application_load_balancer.enabled && var.application_load_balancer.route_53_host_zone_id != "" && var.application_load_balancer.host != "" ? {
      name    = aws_route53_record.main_alb_record[0].name
      fqdn    = aws_route53_record.main_alb_record[0].fqdn
      zone_id = aws_route53_record.main_alb_record[0].zone_id
    } : null
    additional_records = {
      for idx, record in aws_route53_record.additional_alb_records : idx => {
        name    = record.name
        fqdn    = record.fqdn
        zone_id = record.zone_id
      }
    }
  }
}

output "load_balancer" {
  description = "DNS details of the ALB(s) fronting the service. Use these (e.g. dns_name) to create DNS records such as Cloudflare CNAMEs outside this module."
  value = {
    main = var.application_load_balancer.enabled && var.application_load_balancer.listener_arn != "" ? {
      dns_name = data.aws_lb.main_alb[0].dns_name
      zone_id  = data.aws_lb.main_alb[0].zone_id
      host     = var.application_load_balancer.host
    } : null
    additional = {
      for idx, alb in var.additional_load_balancers : idx => {
        dns_name = data.aws_lb.additional_albs[idx].dns_name
        zone_id  = data.aws_lb.additional_albs[idx].zone_id
        host     = alb.host
      }
      if alb.enabled && alb.listener_arn != ""
    }
  }
}

output "log_anomaly_detector_arn" {
  description = "ARN of the CloudWatch Logs Anomaly Detector (if enabled)"
  value       = var.log_anomaly_detection.enabled ? aws_cloudwatch_log_anomaly_detector.this[0].arn : null
}

output "log_anomaly_detector_name" {
  description = "Name of the CloudWatch Logs Anomaly Detector (if enabled)"
  value       = var.log_anomaly_detection.enabled ? aws_cloudwatch_log_anomaly_detector.this[0].detector_name : null
}
