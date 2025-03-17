module "demo_ecs_service" {
  source  = "delivops/ecs-service/aws"
  version = "0.0.24"

  ecs_cluster_name   = var.cluster_name
  ecs_service_name   = "demo"
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnets
  security_group_ids = [aws_security_group.gatus_sg.id]

  application_load_balancer = {
    container_port    = 80
    listener_arn      = module.production_alb.listeners["ex-https"].arn
    host              = "demo.internal.delivops.com"
    path              = "/*"
    health_check_path = "/health"
  }
}