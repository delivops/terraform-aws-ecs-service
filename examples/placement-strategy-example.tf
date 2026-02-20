module "placement_ecs_service" {
  source = "../"

  ecs_cluster_name   = var.cluster_name
  ecs_service_name   = "placement"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids
  ecs_launch_type    = "EC2"

  capacity_provider_strategy = "my-capacity-provider"

  placement_strategy = [
    {
      type  = "binpack"
      field = "memory"
    }
  ]

  placement_constraints = [
    {
      type = "distinctInstance"
    }
  ]
}
// 5 resources
