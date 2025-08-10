output "records_created" {
  description = "List of DNS records created in Cloudflare"
  value       = { for k, v in cloudflare_record.dns_records : k => {
    name    = v.name
    value   = v.value
    proxied = v.proxied
    ttl     = v.ttl
  }}
}

output "record_count" {
  description = "Number of DNS records created"
  value       = length(cloudflare_record.dns_records)
}

output "record_names" {
  description = "List of DNS record names created"
  value       = [for record in cloudflare_record.dns_records : record.name]
}
