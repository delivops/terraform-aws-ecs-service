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

variable "application_load_balancer" {
  description = "alb"
  type = object({
    enabled                          = optional(bool, false)
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


variable "service_connect" {
  type = object({
    enabled = optional(bool, false)
    type    = optional(string, "client-only")
    port    = optional(number, 80)
    additional_ports = optional(list(object({
      name = string
      port = number
    })), [])
  })

  default = {}

  validation {
    condition     = contains(["client-only", "client-server"], var.service_connect.type)
    error_message = "Allowed values for service_connect.type are: client-only, client-server."
  }
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
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

variable "desired_count" {
  description = "Desired number of tasks"
  type        = number
  default     = 1
}

variable "ecs_launch_type" {
  description = "Launch type for the ECS service"
  type        = string
  default     = "FARGATE"
}
variable "deployment" {
  description = "Deployment configuration for the ECS service"
  type = object({
    min_healthy_percent     = optional(number, 100)
    max_healthy_percent     = optional(number, 200)
    circuit_breaker_enabled     = optional(bool, true)
    rollback_enabled            = optional(bool, true)
    cloudwatch_alarm_enabled    = optional(bool, false)
    cloudwatch_alarm_rollback   = optional(bool, true)
    cloudwatch_alarm_names       = optional(list(string), [])
  })
  default = {}

}

variable "cpu_auto_scaling" {
  description = "value for auto scaling"
  default     = {}
  type = object({
    enabled            = optional(bool, false)
    min_replicas       = optional(number, 1)
    max_replicas       = optional(number, 1)
    scale_in_cooldown  = optional(number, 300)
    scale_out_cooldown = optional(number, 300)
    target_value       = optional(number, 70)
  })
}

variable "memory_auto_scaling" {
  description = "value for auto scaling"
  default     = {}
  type = object({
    enabled            = optional(bool, false)
    min_replicas       = optional(number, 1)
    max_replicas       = optional(number, 1)
    scale_in_cooldown  = optional(number, 300)
    scale_out_cooldown = optional(number, 300)
    target_value       = optional(number, 70)

  })
}
variable "sqs_auto_scaling" {
  description = "value for auto scaling"
  default     = {}
  type = object({
    enabled             = optional(bool, false)
    min_replicas        = optional(number, 1)
    max_replicas        = optional(number, 1)
    queue_name          = optional(string, "")
    scale_in_step       = optional(number, 1)
    scale_out_step      = optional(number, 1)
    scale_in_cooldown   = optional(number, 300)
    scale_out_cooldown  = optional(number, 300)
    scale_in_threshold  = optional(number, 10)
    scale_out_threshold = optional(number, 100)
  })

}
