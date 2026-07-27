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
  description = "ARN of a KMS key to encrypt the CloudWatch log group. Empty uses the default AWS-owned key. The key policy must allow the CloudWatch Logs service principal in this region."
  type        = string
  default     = ""
}

variable "application_load_balancer" {
  description = "Primary load balancer for the service: target group, health checks, listener rule (host/path routing or fixed-response), stickiness, and an optional Route53 alias record. Set enabled = true to attach the service to an existing ALB listener, or protocol = \"TCP\" with nlb_arn to have the module create an NLB listener."
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
  description = "ECS Service Connect configuration. type = client-only joins the namespace as a client; client-server also advertises this service (default port plus optional additional_ports) for discovery by other services. The namespace is assumed to share the cluster name."
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

variable "container_image" {
  description = "Docker image for the container"
  type        = string
  default     = "nginx:latest"
}

variable "desired_count" {
  description = "Number of tasks at service creation. Not reconciled afterwards — desired_count is in the service's ignore_changes, so an autoscaler or deploy pipeline can own the running count without Terraform reverting it."
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
    error_message = "Fargate requires network_mode = \"awsvpc\"."
  }

  validation {
    condition     = var.network_mode != "awsvpc" || (length(var.subnet_ids) > 0 && length(var.security_group_ids) > 0)
    error_message = "network_mode = \"awsvpc\" requires subnet_ids and security_group_ids."
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
  description = "Name of an existing ECS capacity provider for the service. When set, the service uses it instead of a plain launch_type. Leave empty to use ecs_launch_type directly."
  type        = string
  default     = ""
}

variable "ecr" {
  description = "ECR repository configuration. mutability = IMMUTABLE rejects a push that would overwrite an existing tag, so tags must be unique per build (a commit SHA rather than a moving branch name)."
  type = object({
    create_repo         = optional(bool, false)
    repo_name           = optional(string, "")
    mutability          = optional(string, "IMMUTABLE")
    scan_on_push        = optional(bool, true)
    kms_key_id          = optional(string, "") # KMS key ARN. Empty uses AES256. Setting this replaces the repository.
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
    error_message = "ecr.mutability must be MUTABLE or IMMUTABLE."
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

variable "task_role" {
  description = "IAM role the container assumes — the application's own permissions. Either create it here (create = true, with inline_policy and attach_policies) or supply an existing one (arn). It starts with no permissions: only the application knows what it needs."
  type = object({
    create          = optional(bool, false)
    arn             = optional(string, "")
    name            = optional(string, "")
    inline_policy   = optional(string, "")
    attach_policies = optional(list(string), [])
  })
  default = {}

  validation {
    condition     = !(var.task_role.create && var.task_role.arn != "")
    error_message = "task_role.create and task_role.arn are mutually exclusive: either the module creates the role or you supply one."
  }

  validation {
    condition     = var.task_role.arn == "" || startswith(var.task_role.arn, "arn:")
    error_message = "task_role.arn must be a full IAM role ARN, not a role name."
  }
}

variable "execution_role" {
  description = "IAM role the ECS agent assumes to start the task — ECR pull, log write, secret fetch. Either create it here (create = true) or supply an existing one (arn); a single execution role shared across services is a common pattern. When created, AmazonECSTaskExecutionRolePolicy is attached by default, since that policy is the same for every service. It does not cover secrets: add ssm:GetParameters or secretsmanager:GetSecretValue via inline_policy if the task definition references any."
  type = object({
    create                  = optional(bool, false)
    arn                     = optional(string, "")
    name                    = optional(string, "")
    inline_policy           = optional(string, "")
    attach_policies         = optional(list(string), [])
    attach_execution_policy = optional(bool, true)
  })
  default = {}

  validation {
    condition     = !(var.execution_role.create && var.execution_role.arn != "")
    error_message = "execution_role.create and execution_role.arn are mutually exclusive: either the module creates the role or you supply one."
  }

  validation {
    condition     = var.execution_role.arn == "" || startswith(var.execution_role.arn, "arn:")
    error_message = "execution_role.arn must be a full IAM role ARN, not a role name."
  }
}
