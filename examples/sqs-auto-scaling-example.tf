module "sqs_ecs_service" {
  source = "../"

  ecs_cluster_name   = var.cluster_name
  ecs_service_name   = "sqs"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids
  sqs_auto_scaling = {
    enabled                      = true
    min_replicas                 = 1
    max_replicas                 = 5
    scale_in_cooldown            = 60
    scale_out_cooldown           = 60
    queue_name                   = "my-queue"
    scale_in_datapoints_to_alarm = 15

  }
}

//8 resources to create
//expected no port mapping in the task definition
