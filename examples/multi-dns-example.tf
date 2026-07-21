# Example showing DNS configurations with the ECS service module.
#
# This module manages Route53 records natively. It no longer manages Cloudflare
# records or configures a Cloudflare provider. If you use Cloudflare, create the
# records in your own configuration using the module's `load_balancer` output.

# Example 1: Service with Route53 DNS (managed by the module)
module "ecs_service_route53" {
  source             = "../"
  ecs_cluster_name   = var.cluster_name
  ecs_service_name   = "route53-only"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids
  initial_role       = aws_iam_role.ecs_task_role.arn

  application_load_balancer = {
    enabled               = true
    container_port        = 80
    listener_arn          = var.listener_arn
    host                  = "api-r53.example.com"
    path                  = "/*"
    health_check_path     = "/health"
    route_53_host_zone_id = var.route_53_zone_id
  }
}

# Example 2: Service fronted by an ALB, with Cloudflare DNS managed OUTSIDE the
# module. The module exposes the ALB DNS name via the `load_balancer` output, so
# you own the Cloudflare provider and record in your root configuration.
module "ecs_service_for_cloudflare" {
  source             = "../"
  ecs_cluster_name   = var.cluster_name
  ecs_service_name   = "cloudflare-demo"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids
  initial_role       = aws_iam_role.ecs_task_role.arn

  application_load_balancer = {
    enabled           = true
    container_port    = 80
    listener_arn      = var.listener_arn
    host              = "api-cf.example.com"
    path              = "/*"
    health_check_path = "/health"
    # No route_53_host_zone_id: we manage DNS in Cloudflare below.
  }
}

# To front the second service with Cloudflare (or any external DNS), read the
# module's `load_balancer` output in YOUR own configuration and create the DNS
# record there — e.g. a cloudflare_record with
# content = module.ecs_service_for_cloudflare.load_balancer.main.dns_name.
# The module itself no longer manages Cloudflare.
#
# Shared input variables (cluster_name, vpc_id, subnet_ids, security_group_ids,
# listener_arn, route_53_zone_id) are declared once in examples/variables.tf.
