module "alb_ecs_service" {
  source             = "../"
  ecs_cluster_name   = var.cluster_name
  ecs_service_name   = "alb"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  application_load_balancer = {
    enabled           = true
    container_port    = 7000
    listener_arn      = var.listener_arn
    host              = "demo.internal.delivops.com"
    path              = "/*"
    health_check_path = "/health"
  }
  additional_load_balancers = [
    {
      enabled           = true
      container_port    = 8000
      listener_arn      = var.listener_arn
      host              = "demo123.internal.delivops.com"
      path              = "/*"
      health_check_path = "/heal23th"
    }
  ]
}

//if not put the listener_arn, the plan will failed.check "" {
//create 5 resources + len(var.additional_load_balancers)*2
// expected: 1 port mapping in the task definition
