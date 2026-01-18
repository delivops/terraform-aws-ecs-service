# Basic usage - analyze all logs with default settings
module "service_with_anomaly_detection" {
  source = "../"

  ecs_cluster_name   = var.cluster_name
  ecs_service_name   = "api-service"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  log_anomaly_detection = {
    enabled = true
  }
}

# With error filter - recommended for noisy services
module "service_with_filtered_anomaly_detection" {
  source = "../"

  ecs_cluster_name   = var.cluster_name
  ecs_service_name   = "payment-service"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  log_anomaly_detection = {
    enabled                 = true
    evaluation_frequency    = "FIVE_MIN"
    anomaly_visibility_time = 14
    filter_pattern          = "?ERROR ?error ?Error ?FATAL ?Exception ?Traceback"
  }
}
