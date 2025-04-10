module "with_ecr_ecs_service" {
  source = "../"

  ecs_cluster_name   = var.cluster_name
  ecs_service_name   = "with_ecr"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids
  ecr = {
    create_repo        = true
    tagged_ttl_days    = 30
    versioned_prefixes = ["sha"]

  }
}

//expected: no port mapping in the task definition
//create 5 resources
