# Create Cloudflare DNS records
resource "cloudflare_record" "dns_records" {
  for_each = { for idx, record in var.records : idx => record }

  zone_id = each.value.zone_id
  name    = each.value.name
  value   = each.value.target
  type    = "CNAME"
  ttl     = each.value.proxied ? 1 : each.value.ttl
  proxied = each.value.proxied
  
  comment = each.value.comment != "" ? each.value.comment : "Managed by Terraform - ECS Service ${var.ecs_service_name}"
}
