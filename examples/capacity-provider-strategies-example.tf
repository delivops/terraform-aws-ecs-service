# A guaranteed on-demand floor with Spot above it.
module "floor_plus_spot_ecs_service" {
  source = "../"

  ecs_cluster_name   = var.cluster_name
  ecs_service_name   = "floor-plus-spot"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  capacity_provider_strategies = [
    { capacity_provider = "FARGATE", base = 2, weight = 1 },
    { capacity_provider = "FARGATE_SPOT", weight = 4 },
  ]
}

# Spot only: cheapest, but tasks stay PENDING when Spot has no capacity.
module "spot_only_ecs_service" {
  source = "../"

  ecs_cluster_name   = var.cluster_name
  ecs_service_name   = "spot-only"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  capacity_provider_strategies = [{ capacity_provider = "FARGATE_SPOT" }]
}

# Let the cluster's default_capacity_provider_strategy decide.
module "cluster_default_ecs_service" {
  source = "../"

  ecs_cluster_name   = var.cluster_name
  ecs_service_name   = "cluster-default"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  use_cluster_default_capacity_provider_strategy = true
}
