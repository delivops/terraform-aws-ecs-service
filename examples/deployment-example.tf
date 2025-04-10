module "deployment_ecs_service" {
  source = "../"

  ecs_cluster_name   = var.cluster_name
  ecs_service_name   = "deployment"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  deployment = {
    min_healthy_percent       = 50
    max_healthy_percent       = 100
    circuit_breaker_enabled   = true
    rollback_enabled          = true
    cloudwatch_alarm_enabled  = true
    cloudwatch_alarm_rollback = true
    cloudwatch_alarm_names    = ["lot-of-messages-in-queue"]
  }

}

//expected: no port mapping in the task definition
//create 3 resources
