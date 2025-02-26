#### ECS Service Variables ####
variable "ecs_service_name" {
  description = "Name of the ECS service."
  type        = string
}

variable "ecs_cluster_name" {
  description = "Name of the ECS cluster."
  type        = string
}

variable "ecs_task_count" {
  description = "Desired number of running tasks in the ECS service."
  type        = number
  default     = 1
}

variable "ecs_launch_type" {
  description = "Launch type for the ECS service (e.g., 'FARGATE' or 'EC2')."
  type        = string
  default     = "FARGATE"
}

variable "log_retention_days" {
  description = "Number of days to retain log events in the CloudWatch log group."
  type        = number
  default     = 7

}

############# Network Configuration #############
variable "vpc_id" {
  description = "ID of the VPC where the ECS service is deployed."
  type        = string
}

variable "security_group_ids" {
  description = "List of security groups attached to the ECS service."
  type        = list(string)
  default     = []
}

variable "subnet_ids" {
  description = "List of subnets for the ECS service."
  type        = list(string)
  default     = []
}

variable "assign_public_ip" {
  description = "Enable public IP assignment for ECS tasks."
  type        = bool
  default     = false
}

############### Load Balancer Configuration ###############
variable "lb_listener_arn" {
  description = "ARN of the Load Balancer listener."
  type        = string
  default     = null
}

variable "host_based_routing" {
  description = "List of host-based routing rules."
  type = list(object({
    host     = string
    priority = number
  }))
  default = []
}

variable "path_based_routing" {
  description = "List of path-based routing rules."
  type = list(object({
    path     = string
    priority = number
  }))
  default = []
}

variable "enable_target_group" {
  description = "Enable target group creation."
  type        = bool
  default     = false
}

variable "target_group_name" {
  description = "Name of the target group."
  type        = string
  default     = "target-group"
}

variable "target_group_port" {
  description = "Port exposed by the target group."
  type        = number
  default     = 80
}

variable "target_group_protocol" {
  description = "Protocol used by the target group (HTTP/HTTPS)."
  type        = string
  default     = "HTTP"
}

variable "target_group_type" {
  description = "Type of target group (IP/INSTANCE)."
  type        = string
  default     = "ip"

}


########## Health Check Configuration ##########

variable "health_check_path" {
  description = "Path for health check requests."
  type        = string
  default     = "/"
}

variable "health_check_protocol" {
  description = "Protocol for health checks."
  type        = string
  default     = "HTTP"
}

variable "health_check_interval_sec" {
  description = "Time interval between health checks (in seconds)."
  type        = number
  default     = 30
}

variable "health_check_threshold_healthy" {
  description = "Number of successful checks before a target is considered healthy."
  type        = number
  default     = 3
}

variable "health_check_threshold_unhealthy" {
  description = "Number of failed checks before a target is considered unhealthy."
  type        = number
  default     = 2
}

variable "health_check_timeout_sec" {
  description = "Timeout for health check responses (in seconds)."
  type        = number
  default     = 5
}

variable "health_check_matcher" {
  description = "String to match against the response body for a successful health check."
  type        = string
  default     = "200"

}


############# Auto scaling Configuration #############

variable "enable_autoscaling" {
  description = "Enable auto-scaling for the ECS service."
  type        = bool
  default     = false
}

variable "min_task_count" {
  description = "Minimum number of running tasks."
  type        = number
  default     = 1
}

variable "max_task_count" {
  description = "Maximum number of running tasks."
  type        = number
  default     = 10
}

variable "scale_on_cpu_usage" {
  description = "Enable auto-scaling based on CPU usage."
  type        = bool
  default     = false
}

variable "scale_on_cpu_target" {
  description = "Target CPU utilization percentage for scaling."
  type        = number
  default     = 50
}

variable "scale_on_memory_usage" {
  description = "Enable auto-scaling based on memory usage."
  type        = bool
  default     = false
}

variable "scale_on_memory_target" {
  description = "Target memory utilization percentage for scaling."
  type        = number
  default     = 50
}

variable "scale_on_alarm_usage" {
  description = "Enable auto-scaling based on CloudWatch alarms."
  type        = bool
  default     = false

}

variable "queue_name" {
  description = "Queue name for scaling."
  type        = string
  default     = ""
}

variable "scale_by_alarm_in_adjustment" {
  description = "The adjustment for scaling in by alarm."
  type        = number
  default     = -1

}

variable "scale_by_alarm_out_adjustment" {
  description = "The adjustment for scaling out by alarm."
  type        = number
  default     = 1

}

variable "queue_scale_in_threshold" {
  description = "Number of messages in the queue that triggers scaling in (reducing tasks)."
  type        = number
  default     = 10
}

variable "queue_scale_out_threshold" {
  description = "Number of messages in the queue that triggers scaling out (increasing tasks)."
  type        = number
  default     = 100
}

variable "scale_cooldown_in_sec" {
  description = "Cooldown period (seconds) before scaling in."
  type        = number
  default     = 300
}

variable "scale_cooldown_out_sec" {
  description = "Cooldown period (seconds) before scaling out."
  type        = number
  default     = 300
}

############# Container Configuration #############
variable "container_image" {
  description = "Docker image for the ECS task."
  type        = string
  default     = "nginx:stable"
}

variable "container_name" {
  description = "Name of the container running in the ECS task."
  type        = string
  default     = "app"
}

variable "container_port" {
  description = "Port exposed by the container."
  type        = number
  default     = 80
}

variable "ecs_task_cpu" {
  description = "CPU units allocated for the ECS task."
  type        = number
  default     = 256
}

variable "ecs_task_memory" {
  description = "Memory allocated for the ECS task (in MB)."
  type        = number
  default     = 512
}

####### Deployment Configuration #######
variable "deployment_circuit_breaker" {
  description = "Enable deployment circuit breaker."
  type        = bool
  default     = false
}

variable "deployment_rollback" {
  description = "Enable automatic rollback on failure."
  type        = bool
  default     = false
}

variable "deployment_cloudwatch_alarm_enabled" {
  description = "Enable CloudWatch alarm for deployment."
  type        = bool
  default     = false
}

variable "deployment_cloudwatch_alarm_names" {
  description = "CloudWatch alarm names."
  type        = list(string)
  default     = []
}

variable "deployment_cloudwatch_alarm_rollback" {
  description = "Enable rollback on alarm trigger."
  type        = bool
  default     = false
}

variable "deployment_min_healthy" {
  description = "Minimum healthy percent during deployment."
  type        = number
  default     = 100
}

variable "deployment_max_percent" {
  description = "Maximum percentage of tasks during deployment."
  type        = number
  default     = 200
}