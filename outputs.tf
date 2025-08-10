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

output "cloudflare_records" {
  description = "Cloudflare DNS records created"
  value = {
    main_record = var.application_load_balancer.enabled && var.application_load_balancer.cloudflare_zone_id != "" && var.application_load_balancer.host != "" ? {
      name    = cloudflare_record.main_alb_record[0].name
      value = cloudflare_record.main_alb_record[0].value
      zone_id = cloudflare_record.main_alb_record[0].zone_id
      proxied = cloudflare_record.main_alb_record[0].proxied
      type    = cloudflare_record.main_alb_record[0].type
    } : null
    additional_records = {
      for idx, record in cloudflare_record.additional_alb_records : idx => {
        name    = record.name
        value = record.value
        zone_id = record.zone_id
        proxied = record.proxied
        type    = record.type
      }
    }
  }
}

output "alb_dns_info" {
  description = "ALB DNS information for Cloudflare module"
  value = var.application_load_balancer.enabled ? {
    dns_name = try(data.aws_lb.main_alb[0].dns_name, null)
    zone_id  = try(data.aws_lb.main_alb[0].zone_id, null)
    arn      = try(data.aws_lb.main_alb[0].arn, null)
  } : null
}
