#### ECS Service Variables ####
variable "service_name" {
  description = "The name of the ECS service."
  type        = string
}

variable "cluster_name" {
  description = "The Name of the ECS cluster."
  type        = string
}

variable "desired_count" {
  description = "The desired count of the ECS service."
  type        = number
  default     = 1
}
variable "container_name" {
  description = "The name of the container."
  type        = string
  default     = "app"
}

############# Network Configuration #############
variable "vpc_id" {
  description = "The VPC ID where the target group is located."
  type        = string
  default     = ""
}
variable "security_groups" {
  description = "The security groups for the ECS service."
  type        = list(string)
  default     = []
}

variable "subnets" {
  description = "The subnets for the ECS service."
  type        = list(string)
  default     = []
}

variable "assign_public_ip" {
  description = "Whether to assign a public IP."
  type        = bool
  default     = false
}
variable "listener_arn" {
  description = "ARN of the load balancer."
  type        = string
  default     = null
}

variable "host_rule_priority" {
  description = "Priority for the host rule."
  type        = number
  default     = 1000
}

variable "host_header_value" {
  description = "Host header value for the listener rule."
  type        = string
  default     = ""
}

variable "path_rule_priority" {
  description = "Priority for the path rule."
  type        = number
  default     = 1000
}

variable "path_pattern_value" {
  description = "Path pattern value for the listener rule."
  type        = string
  default     = ""
}
variable "container_port" {
  description = "The port of the container."
  type        = number
  default     = 80
}
variable "enable_target_group" {
  description = "Whether the target group is enabled."
  type        = bool
  default     = true

}
variable "target_group_name" {
  description = "The name of the target group."
  type        = string
  default     = "target-group"
}

variable "target_group_port" {
  description = "The port of the target group."
  type        = number
  default     = 80
}

variable "target_group_protocol" {
  description = "The protocol of the target group."
  type        = string
  default     = "HTTP"
}


variable "target_type" {
  description = "The target type of the target group."
  type        = string
  default     = "ip"
}

variable "health_check_healthy_threshold" {
  description = "Healthy threshold for the health check."
  type        = number
  default     = 3
}

variable "health_check_interval" {
  description = "Interval for the health check."
  type        = number
  default     = 30
}

variable "health_check_protocol" {
  description = "Protocol for the health check."
  type        = string
  default     = "HTTP"
}

variable "health_check_matcher" {
  description = "Matcher for the health check."
  type        = string
  default     = "200"
}

variable "health_check_path" {
  description = "Path for the health check."
  type        = string
  default     = "/"
}

variable "health_check_unhealthy_threshold" {
  description = "Unhealthy threshold for the health check."
  type        = number
  default     = 2
}
variable "health_check_timeout" {
  description = "The timeout for the health check."
  type        = number
  default     = 5
}

############# Deployment Configuration #############

variable "deployment_cloudwatch_alarm_enabled" {
  description = "Whether to enable CloudWatch alarms."
  type        = bool
  default     = false
}
variable "deployment_cloudwatch_alarm_names" {
  description = "The CloudWatch alarm names."
  type        = list(string)
  default     = []
}
variable "deployment_cloudwatch_alarm_rollback_enabled" {
  description = "Whether to rollback on CloudWatch alarms."
  type        = bool
  default     = false
}

variable "deployment_circuit_breaker_enabled" {
  description = "Whether to enable deployment circuit breaker."
  type        = bool
  default     = false

}
variable "deployment_circuit_breaker_rollback_enabled" {
  description = "Whether to enable deployment circuit breaker."
  type        = bool
  default     = false

}
variable "deployment_minimum_healthy_percent" {
  description = "The minimum healthy percent for deployment."
  default     = 100
}

variable "deployment_maximum_percent" {
  description = "The maximum percent for deployment."
  type        = number
  default     = 200
}

############# Autoscaling Configuration #############

variable "scaling_enabled" {
  description = "Whether to enable scaling."
  type        = bool
  default     = false
}
variable "min_capacity" {
  description = "Minimum number of tasks for scaling"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum number of tasks for scaling"
  type        = number
  default     = 10
}
variable "scale_by_cpu_target_value" {
  description = "The target value for scaling by CPU."
  type        = number
  default     = 50
}
variable "scale_by_cpu_in_cooldown" {
  description = "The cooldown for scaling in by CPU."
  type        = number
  default     = 300
}

variable "scale_by_cpu_out_cooldown" {
  description = "The cooldown for scaling out by CPU."
  type        = number
  default     = 300
}

variable "scale_by_memory_target_value" {
  description = "The target value for scaling by memory."
  type        = number
  default     = 50
}

variable "scale_by_memory_in_cooldown" {
  description = "The cooldown for scaling in by memory."
  type        = number
  default     = 300
}

variable "scale_by_memory_out_cooldown" {
  description = "The cooldown for scaling out by memory."
  type        = number
  default     = 300
}

############## Execution Role Configuration #############

variable "execution_role_arn" {
  description = "The ARN of the execution role."
  type        = string
  default     = ""

}