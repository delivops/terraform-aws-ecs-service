# Cloudflare DNS Addon Module

This optional addon module creates Cloudflare DNS records pointing to your ALB. Use it alongside the main ECS module without any code duplication.

## Features

- ✅ **Zero Code Duplication**: Just pass ALB DNS name from main module
- ✅ **Completely Optional**: Only loads Cloudflare provider when used
- ✅ **Simple Interface**: Just specify records to create
- ✅ **Multiple Records**: Support unlimited DNS records per service
- ✅ **Proxy Control**: Enable/disable Cloudflare proxy per record

## Quick Example

```terraform
# 1. Main ECS service
module "ecs_service" {
  source = "path/to/main/module"
  # ... your ECS configuration
}

# 2. Optional Cloudflare DNS
module "cloudflare_dns" {
  count  = var.cloudflare_zone_id != "" ? 1 : 0
  source = "path/to/main/module/modules/cloudflare-dns"

  records = [
    {
      name    = "api.example.com"
      target  = module.ecs_service.alb_dns_info.dns_name
      zone_id = var.cloudflare_zone_id
      proxied = true
    }
  ]
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| records | List of DNS records to create | `list(object({...}))` | `[]` | yes |
| ecs_service_name | ECS service name for comments | `string` | `""` | no |

### Record Configuration

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name | Domain name (e.g., "api.example.com") | `string` | n/a | yes |
| target | ALB DNS name to point to | `string` | n/a | yes |
| zone_id | Cloudflare zone ID | `string` | n/a | yes |
| proxied | Enable Cloudflare proxy (orange cloud) | `bool` | `true` | no |
| ttl | TTL for non-proxied records | `number` | `300` | no |
| comment | Comment for the record | `string` | `""` | no |

## Full Example

```terraform
module "cloudflare_dns" {
  source = "./modules/cloudflare-dns"

  ecs_service_name = "my-api"
  
  records = [
    {
      name    = "api.example.com"
      target  = module.ecs_service.alb_dns_info.dns_name
      zone_id = "your-cloudflare-zone-id"
      proxied = true
      comment = "Main API endpoint"
    },
    {
      name    = "api-staging.example.com"
      target  = module.ecs_service.alb_dns_info.dns_name
      zone_id = "your-cloudflare-zone-id"
      proxied = false
      ttl     = 60
      comment = "Staging API endpoint"
    }
  ]
}
```

## Prerequisites

1. **Cloudflare API Token**: Set `CLOUDFLARE_API_TOKEN` environment variable
2. **Main ECS Module**: Must be deployed first to get ALB DNS name

## Environment Setup

```bash
export CLOUDFLARE_API_TOKEN="your-api-token"
```

## Outputs

| Name | Description |
|------|-------------|
| records_created | Map of all DNS records created |
| record_count | Number of records created |
| record_names | List of DNS record names |

## Why This Approach?

1. **🚫 No Code Duplication**: You don't repeat your ECS configuration
2. **🔌 Optional**: Main module works fine without this addon
3. **🧩 Modular**: Each module has a single responsibility
4. **⚡ Simple**: Just pass ALB DNS name, no complex listener ARN parsing
5. **📈 Scalable**: Add unlimited DNS records per service
