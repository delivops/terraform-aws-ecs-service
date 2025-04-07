variable "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
}

variable "ecs_service_name" {
  description = "Name of the ECS service"
  type        = string
}

variable "log_retention_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 7
}

# Target group variables
variable "application_load_balancer" {
  description = "alb"
  type = object({
    container_port                   = optional(number, 80)
    listener_arn                     = optional(string, "")
    host                             = optional(string, "")
    path                             = optional(string, "/*")
    protocol                         = optional(string, "HTTP")
    health_check_path                = optional(string, "/health")
    health_check_matcher             = optional(string, "200")
    health_check_interval_sec        = optional(number, 30)
    health_check_timeout_sec         = optional(number, 5)
    health_check_threshold_healthy   = optional(number, 3)
    health_check_threshold_unhealthy = optional(number, 3)
    health_check_protocol            = optional(string, "HTTP")

  })
  default = {}
}
variable "service_connect_enabled" {
  description = "bool for service connect"
  default = false
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

# Task definition variables
variable "ecs_task_cpu" {
  description = "CPU units for the ECS task"
  type        = number
  default     = 256
}

variable "ecs_task_memory" {
  description = "Memory for the ECS task in MiB"
  type        = number
  default     = 512
}

variable "container_name" {
  description = "Name of the container"
  type        = string
  default     = "app"
}

variable "container_image" {
  description = "Docker image for the container"
  type        = string
  default     = "nginx:latest"
}

# ECS service variables
variable "ecs_task_count" {
  description = "Desired number of tasks"
  type        = number
  default     = 1
}

variable "ecs_launch_type" {
  description = "Launch type for the ECS service"
  type        = string
  default     = "FARGATE"
}

variable "deployment_min_healthy" {
  description = "Minimum healthy percent during deployment"
  type        = number
  default     = 100
}

variable "deployment_max_percent" {
  description = "Maximum percent during deployment"
  type        = number
  default     = 200
}

variable "deployment_circuit_breaker" {
  description = "Enable deployment circuit breaker"
  type        = bool
  default     = true
}

variable "deployment_rollback" {
  description = "Enable deployment rollback"
  type        = bool
  default     = true
}

variable "security_group_ids" {
  description = "Security group IDs for the ECS tasks"
  type        = list(string)
}

variable "subnet_ids" {
  description = "Subnet IDs for the ECS tasks"
  type        = list(string)
}

variable "assign_public_ip" {
  description = "Assign public IP to ECS tasks"
  type        = bool
  default     = false
}

# Deployment alarm variables
variable "deployment_cloudwatch_alarm_enabled" {
  description = "Enable CloudWatch alarms for deployment"
  type        = bool
  default     = false
}

variable "deployment_cloudwatch_alarm_names" {
  description = "Names of CloudWatch alarms for deployment"
  type        = list(string)
  default     = []
}

variable "deployment_cloudwatch_alarm_rollback" {
  description = "Enable rollback on CloudWatch alarm"
  type        = bool
  default     = true
}

# Autoscaling variables
variable "enable_autoscaling" {
  description = "Enable autoscaling for the ECS service"
  type        = bool
  default     = false
}

variable "min_task_count" {
  description = "Minimum number of tasks"
  type        = number
  default     = 1
}

variable "max_task_count" {
  description = "Maximum number of tasks"
  type        = number
  default     = 10
}

# CPU-based scaling
variable "scale_on_cpu_usage" {
  description = "Enable scaling based on CPU usage"
  type        = bool
  default     = false
}

variable "scale_on_cpu_target" {
  description = "Target CPU usage percentage for scaling"
  type        = number
  default     = 70
}

# Memory-based scaling
variable "scale_on_memory_usage" {
  description = "Enable scaling based on memory usage"
  type        = bool
  default     = false
}

variable "scale_on_memory_target" {
  description = "Target memory usage percentage for scaling"
  type        = number
  default     = 70
}

# Alarm-based scaling
variable "scale_on_alarm_usage" {
  description = "Enable scaling based on CloudWatch alarms"
  type        = bool
  default     = false
}

variable "scale_by_alarm_out_adjustment" {
  description = "Number of tasks to add when scaling out"
  type        = number
  default     = 1
}

variable "scale_by_alarm_in_adjustment" {
  description = "Number of tasks to remove when scaling in"
  type        = number
  default     = -1
}

variable "scale_cooldown_in_sec" {
  description = "Cooldown period in seconds for scaling in"
  type        = number
  default     = 300
}

variable "scale_cooldown_out_sec" {
  description = "Cooldown period in seconds for scaling out"
  type        = number
  default     = 300
}

# Queue-based scaling thresholds
variable "queue_scale_in_threshold" {
  description = "Threshold for scaling in based on queue metrics"
  type        = number
  default     = 1
}

variable "queue_scale_out_threshold" {
  description = "Threshold for scaling out based on queue metrics"
  type        = number
  default     = 10
}

variable "queue_name" {
  description = "Name of the SQS queue for scaling metrics"
  type        = string
  default     = ""
}
