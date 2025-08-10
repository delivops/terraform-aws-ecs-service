variable "records" {
  description = "List of DNS records to create in Cloudflare"
  type = list(object({
    name           = string  # The domain name (e.g., "api.example.com")
    target         = string  # The ALB DNS name to point to
    zone_id        = string  # Cloudflare zone ID
    proxied        = optional(bool, true)    # Enable Cloudflare proxy
    ttl            = optional(number, 300)   # TTL for non-proxied records
    comment        = optional(string, "")    # Comment for the record
  }))
  default = []
}

variable "ecs_service_name" {
  description = "Name of the ECS service (for record comments)"
  type        = string
  default     = ""
}
