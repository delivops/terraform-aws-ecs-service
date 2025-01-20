module "ecs_service" {
  source = "../"
  #version            = "0.0.1"

  cluster_name        = "dev-cluster"
  service_name        = "my-service"
  vpc_id              = "vpc-xxx"
  subnets             = ["sxxx"]
  security_groups     = ["xxx"]
  enable_target_group = false


  # Auto Scaling Configuration
  scaling_enabled         = true
  scale_by_memory_enabled = false
  scale_by_cpu_enabled    = false
  scale_by_alarm_enabled  = true
  queue_name              = "queue-ecs"
}


