# Migration Guide: To Single Module Approach

If you're currently using the main module and want to add Cloudflare DNS, or if you're calling multiple modules separately, here's how to migrate to the single `ecs-service-with-dns` module.

## Migration Scenarios

### 1. From Main Module Only → Single Module with Cloudflare

**Before (main module only):**
```hcl
module "my_service" {
  source = "delivops/ecs-service/aws"
  
  ecs_cluster_name   = "my-cluster"
  ecs_service_name   = "my-app"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  application_load_balancer = {
    enabled           = true
    container_port    = 80
    listener_arn      = var.listener_arn
    host              = "my-app.example.com"
    path              = "/*"
    health_check_path = "/"
  }
}
```

**After (single module with Cloudflare):**
```hcl
module "my_service" {
  source = "delivops/ecs-service/aws//modules/ecs-service-with-dns"
  
  ecs_cluster_name   = "my-cluster"
  ecs_service_name   = "my-app"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  application_load_balancer = {
    enabled           = true
    container_port    = 80
    listener_arn      = var.listener_arn
    host              = "my-app.example.com"
    path              = "/*"
    health_check_path = "/"
    
    # Add these lines for Cloudflare DNS
    cloudflare_zone_id = var.cloudflare_zone_id
    cloudflare_proxied = true
    cloudflare_ttl     = 300
  }
}
```

### 2. From Separate Modules → Single Module

**Before (two module calls):**
```hcl
module "ecs_service" {
  source = "delivops/ecs-service/aws"
  
  ecs_cluster_name   = "my-cluster"
  ecs_service_name   = "my-app"
  # ... config ...

  application_load_balancer = {
    enabled           = true
    container_port    = 80
    listener_arn      = var.listener_arn
    host              = "my-app.example.com"
    path              = "/*"
    health_check_path = "/"
  }
}

module "cloudflare_dns" {
  source = "delivops/ecs-service/aws//modules/cloudflare-dns"
  
  ecs_service_name = "my-app"
  
  application_load_balancer = {
    enabled            = true
    host               = "my-app.example.com"
    cloudflare_zone_id = var.cloudflare_zone_id
    cloudflare_proxied = true
    cloudflare_ttl     = 300
    listener_arn       = var.listener_arn
  }
}
```

**After (single module call):**
```hcl
module "my_service" {
  source = "delivops/ecs-service/aws//modules/ecs-service-with-dns"
  
  ecs_cluster_name   = "my-cluster"
  ecs_service_name   = "my-app"
  # ... same config ...

  application_load_balancer = {
    enabled           = true
    container_port    = 80
    listener_arn      = var.listener_arn
    host              = "my-app.example.com"
    path              = "/*"
    health_check_path = "/"
    
    # Cloudflare config merged into ALB object
    cloudflare_zone_id = var.cloudflare_zone_id
    cloudflare_proxied = true
    cloudflare_ttl     = 300
  }
}
```

## Benefits of Migration

1. **Less Code**: Define your service once instead of twice
2. **Simpler Management**: One module call handles everything
3. **Conditional DNS**: Cloudflare is only used if you provide `cloudflare_zone_id`
4. **No Provider Conflicts**: Cloudflare provider only loaded when needed

## Migration Steps

1. **Update module source**: Change to `//modules/ecs-service-with-dns`
2. **Merge configurations**: Add Cloudflare fields to your ALB objects
3. **Remove separate modules**: Delete any separate `cloudflare-dns` module calls
4. **Update outputs**: Reference outputs from the single module
5. **Test**: Run `terraform plan` to verify the changes

## Rollback

If you need to rollback, you can always switch back to the main module by:

1. Changing the source back to the main module
2. Removing Cloudflare fields from ALB objects
3. Adding separate `cloudflare-dns` module calls if needed

The underlying resources remain the same, so the migration is safe and reversible.
