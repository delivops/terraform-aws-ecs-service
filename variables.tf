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

variable "log_kms_key_id" {
  description = "ARN of a KMS key to encrypt the CloudWatch log group. Leave empty to use the default AWS-owned key."
  type        = string
  default     = ""
}

variable "application_load_balancer" {
  description = "Primary load balancer configuration for the service: target group, health checks, listener rule (host/path routing or fixed-response), stickiness, and optional Route53 record. Set enabled = true to attach the service to an existing ALB/NLB listener."
  type = object({
    enabled                          = optional(bool, false)
    container_port                   = optional(number, 80)
    listener_arn                     = optional(string, "")
    nlb_arn                          = optional(string, "")
    nlb_port                         = optional(number, 80)
    host                             = optional(string, "")
    path                             = optional(string, "/*")
    protocol                         = optional(string, "HTTP")
    health_check_path                = optional(string, "/health")
    health_check_matcher             = optional(string, "200")
    health_check_interval_sec        = optional(number, 30)
    health_check_timeout_sec         = optional(number, 10)
    health_check_threshold_healthy   = optional(number, 2)
    health_check_threshold_unhealthy = optional(number, 5)
    health_check_protocol            = optional(string, "HTTP")
    health_check_port                = optional(string, "traffic-port")
    stickiness                       = optional(bool, false)
    stickiness_ttl                   = optional(number, 300)
    cookie_name                      = optional(string, "")
    stickiness_type                  = optional(string, "app_cookie")
    action_type                      = optional(string, "forward")
    target_group_name                = optional(string, "")
    deregister_deregistration_delay  = optional(number, 60)
    route_53_host_zone_id            = optional(string, "")
  })
  default = {}
}

variable "additional_load_balancers" {
  description = "Additional load balancers configuration"
  type = list(object({
    enabled                          = optional(bool, false)
    container_port                   = optional(number, 80)
    listener_arn                     = optional(string, "")
    nlb_arn                          = optional(string, "")
    nlb_port                         = optional(number, 80)
    host                             = optional(string, "")
    path                             = optional(string, "/*")
    protocol                         = optional(string, "HTTP")
    health_check_path                = optional(string, "/health")
    health_check_matcher             = optional(string, "200")
    health_check_interval_sec        = optional(number, 30)
    health_check_timeout_sec         = optional(number, 10)
    health_check_threshold_healthy   = optional(number, 2)
    health_check_threshold_unhealthy = optional(number, 5)
    health_check_protocol            = optional(string, "HTTP")
    health_check_port                = optional(string, "traffic-port")
    stickiness                       = optional(bool, false)
    stickiness_ttl                   = optional(number, 300)
    stickiness_type                  = optional(string, "app_cookie")
    cookie_name                      = optional(string, "")
    action_type                      = optional(string, "forward")
    target_group_name                = optional(string, "")
    deregister_deregistration_delay  = optional(number, 60)
    route_53_host_zone_id            = optional(string, "")
  }))
  default = []
}





variable "service_connect" {
  description = "ECS Service Connect configuration. type = client-only joins the namespace as a client; client-server also advertises this service (default port plus optional additional_ports) for discovery by other services."
  type = object({
    enabled     = optional(bool, false)
    type        = optional(string, "client-only")
    port        = optional(number, 80)
    name        = optional(string, "service")
    timeout     = optional(number, 15)
    appProtocol = optional(string, "http")
    additional_ports = optional(list(object({
      name        = string
      port        = number
      appProtocol = optional(string, "http")
    })), [])
  })

  default = {}

  validation {
    condition     = contains(["client-only", "client-server"], var.service_connect.type)
    error_message = "Allowed values for service_connect.type are: client-only, client-server."
  }

  validation {
    condition     = var.service_connect.enabled == false || contains(["http", "tcp"], var.service_connect.appProtocol)
    error_message = "Allowed values for service_connect.appProtocol are: http, tcp."
  }
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}
variable "security_group_ids" {
  description = "Security group IDs for the ECS tasks. Required when network_mode is 'awsvpc'."
  type        = list(string)
  default     = []
}

variable "subnet_ids" {
  description = "Subnet IDs for the ECS tasks. Required when network_mode is 'awsvpc'."
  type        = list(string)
  default     = []
}

variable "assign_public_ip" {
  description = "Assign public IP to ECS tasks"
  type        = bool
  default     = false
}

variable "enable_execute_command" {
  description = "Enable execute command"
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

variable "gpu_count" {
  description = "Number of GPUs to request for the container (EC2 launch type only). 0 disables GPU resource requirements."
  type        = number
  default     = 0

  validation {
    condition     = var.gpu_count >= 0
    error_message = "gpu_count must be >= 0."
  }
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
  description = "Launch type for the ECS service (FARGATE or EC2)"
  type        = string
  default     = "FARGATE"
  validation {
    condition     = contains(["FARGATE", "EC2"], var.ecs_launch_type)
    error_message = "Valid values for ecs_launch_type are FARGATE or EC2."
  }
}

variable "network_mode" {
  description = "Network mode for the ECS task definition. Fargate requires 'awsvpc'. EC2 supports 'awsvpc', 'bridge', 'host', or 'none'."
  type        = string
  default     = "awsvpc"

  validation {
    condition     = contains(["awsvpc", "bridge", "host", "none"], var.network_mode)
    error_message = "Valid values for network_mode are: awsvpc, bridge, host, none."
  }

  validation {
    condition     = var.ecs_launch_type != "FARGATE" || var.network_mode == "awsvpc"
    error_message = "Fargate launch type requires network_mode = 'awsvpc'."
  }

  validation {
    condition     = var.network_mode != "awsvpc" || (length(var.subnet_ids) > 0 && length(var.security_group_ids) > 0)
    error_message = "subnet_ids and security_group_ids are required when network_mode is 'awsvpc'."
  }
}
variable "deployment" {
  description = "Deployment configuration for the ECS service"
  type = object({
    min_healthy_percent       = optional(number, 100)
    max_healthy_percent       = optional(number, 200)
    circuit_breaker_enabled   = optional(bool, true)
    rollback_enabled          = optional(bool, true)
    cloudwatch_alarm_enabled  = optional(bool, false)
    cloudwatch_alarm_rollback = optional(bool, true)
    cloudwatch_alarm_names    = optional(list(string), [])
  })
  default = {}

}
variable "capacity_provider_strategy" {
  description = "Name of an existing ECS capacity provider to use for the service. When set, the service uses this capacity provider instead of a plain launch_type (EC2/Fargate). Leave empty to use var.ecs_launch_type directly."
  type        = string
  default     = ""
}

variable "ecr" {
  description = "ECR repository configuration"
  type = object({
    create_repo         = optional(bool, false)
    repo_name           = optional(string, "")
    mutability          = optional(string, "IMMUTABLE")
    scan_on_push        = optional(bool, true)
    kms_key_id          = optional(string, "") # KMS key ARN for repo encryption. Empty = AES256.
    untagged_ttl_days   = optional(number, 7)
    tagged_ttl_days     = optional(number, 7)
    protected_prefixes  = optional(list(string), ["main", "master"])
    protected_retention = optional(number, 999999) # Keep nearly forever
    versioned_prefixes  = optional(list(string), ["v", "sha"])
    versioned_retention = optional(number, 30) # How many versioned tags to keep
  })
  default = {}

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.ecr.mutability)
    error_message = "ecr.mutability must be one of: MUTABLE, IMMUTABLE."
  }
}

variable "log_anomaly_detection" {
  description = "CloudWatch Logs Anomaly Detection configuration"
  type = object({
    enabled                 = optional(bool, false)
    evaluation_frequency    = optional(string, "TEN_MIN")
    anomaly_visibility_time = optional(number, 7)
    filter_pattern          = optional(string, "")
  })
  default = {}

  validation {
    condition = contains(
      ["ONE_MIN", "FIVE_MIN", "TEN_MIN", "FIFTEEN_MIN", "THIRTY_MIN", "ONE_HOUR"],
      var.log_anomaly_detection.evaluation_frequency
    )
    error_message = "evaluation_frequency must be one of: ONE_MIN, FIVE_MIN, TEN_MIN, FIFTEEN_MIN, THIRTY_MIN, ONE_HOUR"
  }

  validation {
    condition     = var.log_anomaly_detection.anomaly_visibility_time >= 7 && var.log_anomaly_detection.anomaly_visibility_time <= 90
    error_message = "anomaly_visibility_time must be between 7 and 90 days"
  }
}

variable "placement_strategy" {
  description = "Ordered placement strategy for ECS service (only applicable for EC2 launch type). Type can be binpack, spread, or random."
  type = list(object({
    type  = string
    field = optional(string)
  }))
  default = []

  validation {
    condition     = alltrue([for s in var.placement_strategy : contains(["binpack", "spread", "random"], s.type)])
    error_message = "placement_strategy type must be one of: binpack, spread, random"
  }
}

variable "placement_constraints" {
  description = "Placement constraints for ECS service (only applicable for EC2 launch type). Type can be distinctInstance or memberOf."
  type = list(object({
    type       = string
    expression = optional(string)
  }))
  default = []

  validation {
    condition     = alltrue([for c in var.placement_constraints : contains(["distinctInstance", "memberOf"], c.type)])
    error_message = "placement_constraints type must be one of: distinctInstance, memberOf"
  }
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "initial_role" {
  description = "ARN of an existing IAM role to use for both task role and execution role. Must be a full IAM role ARN (task_role_arn/execution_role_arn require ARNs, not names). Ignored when role.create = true, in which case the module-created role is used instead."
  type        = string
  default     = ""

  validation {
    condition     = var.initial_role == "" || startswith(var.initial_role, "arn:")
    error_message = "initial_role must be a full IAM role ARN (starting with 'arn:'), not a role name."
  }
}

variable "task_role_arn" {
  description = "ARN of the IAM role for the task (application permissions). Overrides the shared/default role. Leave empty to fall back to the module-created role (role.create) or initial_role."
  type        = string
  default     = ""

  validation {
    condition     = var.task_role_arn == "" || startswith(var.task_role_arn, "arn:")
    error_message = "task_role_arn must be a full IAM role ARN (starting with 'arn:'), not a role name."
  }
}

variable "execution_role_arn" {
  description = "ARN of the IAM role for the ECS agent (execution role: ECR pull, log write, secret fetch). Overrides the shared/default role. Leave empty to fall back to the module-created role (role.create) or initial_role."
  type        = string
  default     = ""

  validation {
    condition     = var.execution_role_arn == "" || startswith(var.execution_role_arn, "arn:")
    error_message = "execution_role_arn must be a full IAM role ARN (starting with 'arn:'), not a role name."
  }
}

variable "role" {
  description = "Optionally create a dedicated IAM role for this service, assumable only by the ECS tasks service (ecs-tasks.amazonaws.com). When create = true, the role's ARN becomes the default for both task_role_arn and execution_role_arn, so initial_role need not be set."
  type = object({
    create                  = optional(bool, false)      # Create the role. Default off.
    name                    = optional(string, "")       # Role name. Defaults to "<cluster>_<service>".
    inline_policy           = optional(string, "")       # Inline IAM policy document (JSON, e.g. jsonencode({...})).
    attach_policies         = optional(list(string), []) # Managed policy ARNs to attach.
    attach_execution_policy = optional(bool, false)      # Attach AmazonECSTaskExecutionRolePolicy.
  })
  default = {}
}
