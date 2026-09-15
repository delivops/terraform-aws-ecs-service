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
  description = "Enable ECS Exec (aws ecs execute-command) on the service. Requires a task role: ECS rejects CreateService without one, and that role needs the ssmmessages permissions ECS Exec runs on — this module attaches no policy granting them. Set on the service rather than the task definition, so unlike the task definition inputs it reconciles normally."
  type        = bool
  default     = false

  # Fargate only. On EC2 the instance role stands in for an absent task role, so
  # that combination is left to the API rather than rejected here.
  validation {
    condition = (
      !var.enable_execute_command ||
      var.ecs_launch_type != "FARGATE" ||
      var.task_role.create || var.task_role.arn != ""
    )
    error_message = "enable_execute_command on Fargate requires a task role: ECS Exec needs ssmmessages permissions on the task IAM role, and Fargate has no instance role to fall back to. Set task_role.create = true or task_role.arn."
  }
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
  description = "IAM role the container assumes — the application's own permissions. Either create it here (create = true, with inline_policy and attach_policies) or supply an existing one (arn). It starts with no permissions: only the application knows what it needs. That includes ECS Exec — enable_execute_command needs ssmmessages:CreateControlChannel, CreateDataChannel, OpenControlChannel and OpenDataChannel added via inline_policy."
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

variable "task_definition_template" {
  description = <<-EOT
    A task definition kept up to date by Terraform in its own family,
    "<cluster>_<service>-template" by default, for the deploy pipeline to copy.
    The pipeline reads the latest revision, swaps the image of `container_name`
    for the build it is deploying, and registers the result into the service's
    family. Unlike the write-once task definition the service starts with,
    every change here registers a new template revision, but nothing reaches
    running tasks until the next deploy.

    The container definitions are generated from the keys below, which mirror
    the task config YAML of delivops/ecs-deploy-action: the `container_name`
    container, a secret-file init container, the fluent-bit and otel-collector
    containers, and `sidecars`. Log configuration points at the module's log
    group. The image of `container_name` is `container_image`, a placeholder the
    pipeline replaces. The task and execution roles, network mode and launch
    type come from the module's own inputs.

    - `envs`: environment variables.
    - `secrets`: env var name => Secrets Manager secret ARN; the variable takes
      the value of the JSON key with the same name.
    - `secrets_envs`: [{ id = secret ARN, values = [JSON keys] }]; each key
      becomes an env var of the same name. Mutually exclusive with `secrets`.
    - `secrets_value_from`: env var name => a `valueFrom` used verbatim (an SSM
      parameter, or a whole secret).
    - `secret_files`: secrets downloaded to `secrets_files_path` by an init
      container before the container starts.
    - `writable_dirs`: an empty volume mounted per path, for use with
      `readonly_root_filesystem`.
    - `otel_collector`: set (even to {}) to add the collector. Without
      `image_name`/`image` it runs the public ADOT image with its config read
      from the SSM parameter `ssm_name`.
    - `fluent_bit_collector`: adds fluent-bit from `image_name` or `image` (one
      is required) and routes the application's logs through FireLens.
    - `image_name` on either collector is a repository in this account's ECR
      registry; `image` is a full image reference.
    - `volumes`: extra task volumes, alongside the generated ones.
    - `container_definitions`: extra containers in ECS API shape, appended as-is.
    - `container_overrides`: generated container name => ECS API fields merged
      over it, for anything the keys above don't cover.
    - `replica_count`: published to SSM for the pipeline to set the service's
      desired count on deploy. Leave null for autoscaled services.

    The family name is published to SSM at
    /ecs/<cluster>/<service>/task-definition-template.
  EOT
  type = object({
    enabled                 = optional(bool, false)
    family_suffix           = optional(string, "-template")
    cpu                     = optional(number)
    memory                  = optional(number)
    cpu_architecture        = optional(string, "X86_64")
    operating_system_family = optional(string, "LINUX")
    ephemeral_storage_gib   = optional(number)
    replica_count           = optional(number)

    port                     = optional(number)
    additional_ports         = optional(map(number), {})
    app_protocol             = optional(string, "http")
    command                  = optional(list(string), [])
    entrypoint               = optional(list(string), [])
    stop_timeout             = optional(number)
    envs                     = optional(map(string), {})
    secrets                  = optional(map(string), {})
    secrets_envs             = optional(list(object({ id = string, values = list(string) })), [])
    secrets_value_from       = optional(map(string), {})
    secret_files             = optional(list(string), [])
    secrets_files_path       = optional(string, "/etc/secrets")
    readonly_root_filesystem = optional(bool)
    writable_dirs            = optional(list(string), [])
    health_check = optional(object({
      command      = optional(string)
      interval     = optional(number, 30)
      timeout      = optional(number, 5)
      retries      = optional(number, 3)
      start_period = optional(number, 10)
    }))
    linux_parameters = optional(object({
      init_process_enabled = optional(bool)
      capabilities = optional(object({
        add  = optional(list(string), [])
        drop = optional(list(string), [])
      }))
      tmpfs = optional(list(object({
        container_path = optional(string, "/tmp")
        size           = optional(number, 64)
        mount_options  = optional(list(string), [])
      })), [])
      swappiness         = optional(number)
      max_swap           = optional(number)
      shared_memory_size = optional(number)
      devices = optional(list(object({
        host_path      = string
        container_path = optional(string)
        permissions    = optional(list(string), ["read", "write"])
      })), [])
    }))

    otel_collector = optional(object({
      image_name   = optional(string, "")
      image        = optional(string)
      ssm_name     = optional(string, "adot-config-global.yaml")
      extra_config = optional(string, "")
      metrics_port = optional(number, 8080)
      metrics_path = optional(string, "/metrics")
    }))
    fluent_bit_collector = optional(object({
      image_name       = optional(string, "")
      image            = optional(string)
      extra_config     = optional(string, "extra.conf")
      ecs_log_metadata = optional(bool, true)
      service_name     = optional(string)
    }))

    sidecars = optional(list(object({
      name                     = string
      image                    = string
      enabled                  = optional(bool, true)
      essential                = optional(bool, true)
      port                     = optional(number)
      additional_ports         = optional(map(number), {})
      app_protocol             = optional(string, "http")
      command                  = optional(list(string), [])
      entrypoint               = optional(list(string), [])
      stop_timeout             = optional(number)
      envs                     = optional(map(string), {})
      secrets                  = optional(map(string), {})
      secrets_envs             = optional(list(object({ id = string, values = list(string) })), [])
      secrets_value_from       = optional(map(string), {})
      secret_files             = optional(list(string), [])
      secrets_files_path       = optional(string, "/etc/secrets")
      readonly_root_filesystem = optional(bool)
      writable_dirs            = optional(list(string), [])
      cpu                      = optional(number)
      memory                   = optional(number)
      memory_reservation       = optional(number)
      log_stream_prefix        = optional(string)
      health_check = optional(object({
        command      = optional(string)
        interval     = optional(number, 30)
        timeout      = optional(number, 5)
        retries      = optional(number, 3)
        start_period = optional(number, 10)
      }))
      linux_parameters = optional(object({
        init_process_enabled = optional(bool)
        capabilities = optional(object({
          add  = optional(list(string), [])
          drop = optional(list(string), [])
        }))
        tmpfs = optional(list(object({
          container_path = optional(string, "/tmp")
          size           = optional(number, 64)
          mount_options  = optional(list(string), [])
        })), [])
        swappiness         = optional(number)
        max_swap           = optional(number)
        shared_memory_size = optional(number)
        devices = optional(list(object({
          host_path      = string
          container_path = optional(string)
          permissions    = optional(list(string), ["read", "write"])
        })), [])
      }))
    })), [])

    volumes = optional(list(object({
      name      = string
      host_path = optional(string)
      efs_volume_configuration = optional(object({
        file_system_id          = string
        root_directory          = optional(string)
        transit_encryption      = optional(string)
        transit_encryption_port = optional(number)
        authorization_config = optional(object({
          access_point_id = optional(string)
          iam             = optional(string)
        }))
      }))
    })), [])
    container_definitions = optional(any, [])
    container_overrides   = optional(any, {})
  })
  default = {}

  validation {
    condition = !var.task_definition_template.enabled || (
      var.task_definition_template.cpu != null && var.task_definition_template.memory != null
    )
    error_message = "task_definition_template.cpu and task_definition_template.memory are required when the template is enabled."
  }

  validation {
    condition     = !var.task_definition_template.enabled || var.execution_role.create || var.execution_role.arn != ""
    error_message = "task_definition_template requires an execution role (execution_role.create or execution_role.arn): without one, tasks copied from the template cannot pull from ECR, write logs or read secrets."
  }

  validation {
    condition = !var.task_definition_template.enabled || (
      !can(keys(var.task_definition_template.container_definitions)) && can([for c in var.task_definition_template.container_definitions : c])
    )
    error_message = "task_definition_template.container_definitions must be a list of container definitions."
  }

  validation {
    condition     = contains(["X86_64", "ARM64"], var.task_definition_template.cpu_architecture)
    error_message = "task_definition_template.cpu_architecture must be X86_64 or ARM64."
  }

  validation {
    condition     = can(regex("^[A-Za-z0-9_-]+$", var.task_definition_template.family_suffix))
    error_message = "task_definition_template.family_suffix must be non-empty (an empty suffix would share the service's family, so the pipeline would copy its own last deploy) and contain only letters, digits, hyphens and underscores."
  }

  validation {
    condition = alltrue(concat(
      [length(var.task_definition_template.secrets) == 0 || length(var.task_definition_template.secrets_envs) == 0],
      [for s in var.task_definition_template.sidecars : length(s.secrets) == 0 || length(s.secrets_envs) == 0],
    ))
    error_message = "task_definition_template: set secrets or secrets_envs on a container, not both."
  }

  validation {
    condition = alltrue([
      for s in var.task_definition_template.sidecars :
      can(regex("^[a-zA-Z0-9][a-zA-Z0-9_-]{0,254}$", s.name)) && s.name != "default" && s.log_stream_prefix != "default"
    ])
    error_message = "task_definition_template.sidecars: a name must start with a letter or digit and contain only letters, digits, hyphens and underscores; \"default\" is reserved as a name and as a log_stream_prefix."
  }

  validation {
    condition = alltrue([
      for s in var.task_definition_template.sidecars :
      s.memory == null || s.memory_reservation == null ? true : s.memory_reservation <= s.memory
    ])
    error_message = "task_definition_template.sidecars: memory_reservation must not exceed memory."
  }

  validation {
    condition = alltrue(concat(
      [contains(["http", "http2", "grpc", "tcp"], var.task_definition_template.app_protocol)],
      [for s in var.task_definition_template.sidecars : contains(["http", "http2", "grpc", "tcp"], s.app_protocol)],
    ))
    error_message = "task_definition_template: app_protocol must be http, http2, grpc or tcp."
  }

  validation {
    condition = alltrue(concat(
      [for name in keys(var.task_definition_template.additional_ports) : can(regex("^[a-z][a-z0-9_-]{0,63}$", name)) && name != "default"],
      flatten([for s in var.task_definition_template.sidecars : [for name in keys(s.additional_ports) : can(regex("^[a-z][a-z0-9_-]{0,63}$", name))]]),
      [for s in var.task_definition_template.sidecars : s.port == null ? true : can(regex("^[a-z][a-z0-9_-]{0,63}$", "${s.name}-${s.port}-tcp"))],
    ))
    error_message = "task_definition_template: port mapping names must start with a lowercase letter and contain only lowercase letters, digits, hyphens and underscores, up to 64 characters. That covers additional_ports keys, and the <name>-<port>-tcp name of a sidecar with a port, so such a sidecar's name must be lowercase. The application's additional_ports cannot use \"default\", which is its main port's name."
  }

  validation {
    condition     = var.task_definition_template.fluent_bit_collector == null ? true : (trimspace(var.task_definition_template.fluent_bit_collector.image_name) != "" || var.task_definition_template.fluent_bit_collector.image != null)
    error_message = "task_definition_template.fluent_bit_collector needs image_name or image; leave it null to run without fluent-bit."
  }

  validation {
    condition     = var.task_definition_template.replica_count == null ? true : var.task_definition_template.replica_count >= 0 && floor(var.task_definition_template.replica_count) == var.task_definition_template.replica_count
    error_message = "task_definition_template.replica_count must be a non-negative whole number."
  }
}
