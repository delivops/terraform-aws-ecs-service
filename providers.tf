provider "cloudflare" {
  api_token = var.cloudflare_api_token != "" ? var.cloudflare_api_token : "1234567890abcdef1234567890abcdef12345678"
}
