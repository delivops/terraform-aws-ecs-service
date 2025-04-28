module "schedule_ecs_service" {
  source = "../"

  ecs_cluster_name   = var.cluster_name
  ecs_service_name   = "schedule-demo"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  schedule_auto_scaling = {
    enabled = true
    schedules = [
      {
        schedule_name       = "scale-up-morning"
        min_capacity        = 2
        max_capacity        = 10
        desired_capacity    = 5
        schedule_expression = "cron(0 9 * * ? *)" # Every day at 09:00 UTC
      },
      {
        schedule_name       = "scale-down-night"
        min_capacity        = 1
        max_capacity        = 3
        schedule_expression = "cron(0 22 * * ? *)" # Every day at 22:00 UTC
        time_zone           = "Asia/Jerusalem"
      }
    ]
  }
}
//resources: 4 + len(var.schedule_auto_scaling.schedules)
