########################
# Task definition template: container definitions
#########################
# Builds the template's containers from var.task_definition_template, following
# the rules delivops/ecs-deploy-action applies to the same keys, so a service
# moves between the two without its running task definition changing.
#
# Object attributes are filtered with `if v != null` instead of choosing between
# object literals with a conditional: a conditional requires both results to
# have the same type, and these objects differ by which attributes they carry.

locals {
  tdt = var.task_definition_template

  tdt_bridge = var.network_mode == "bridge"

  tdt_log_options = {
    "awslogs-group"  = local.tdt_log_group
    "awslogs-region" = local.tdt_region
  }

  tdt_fluent_bit = try(trimspace(local.tdt.fluent_bit_collector.image_name) != "" || local.tdt.fluent_bit_collector.image != null, false)
  tdt_otel       = local.tdt.otel_collector != null
  tdt_otel_custom = try(
    trimspace(local.tdt.otel_collector.image_name) != "" || local.tdt.otel_collector.image != null,
    false
  )

  # The application's writable_dirs are mounted into every container the
  # application owns (its init container, fluent-bit, otel-collector), not into
  # sidecars, which declare their own.
  tdt_app_writable_mounts = [
    for d in local.tdt.writable_dirs : {
      sourceVolume  = "writable-${replace(trim(d, "/"), "/", "-")}"
      containerPath = d
    }
  ]

  # The application container and each enabled sidecar, reduced to one shape so
  # a single expression builds both.
  tdt_specs = concat(
    [{
      name                  = var.container_name
      image                 = var.container_image
      essential             = true
      is_app                = true
      port                  = local.tdt.port
      additional_ports      = local.tdt.additional_ports
      app_protocol          = local.tdt.app_protocol
      command               = local.tdt.command
      entrypoint            = local.tdt.entrypoint
      stop_timeout          = local.tdt.stop_timeout
      envs                  = local.tdt.envs
      secrets               = local.tdt.secrets
      secrets_envs          = local.tdt.secrets_envs
      secrets_value_from    = local.tdt.secrets_value_from
      secret_files          = local.tdt.secret_files
      secrets_files_path    = local.tdt.secrets_files_path
      readonly              = local.tdt.readonly_root_filesystem
      health_check          = local.tdt.health_check
      linux_parameters      = local.tdt.linux_parameters
      cpu                   = null
      memory                = null
      memory_reservation    = null
      firelens              = local.tdt_fluent_bit
      log_stream_prefix     = "/default"
      main_port_name        = "default"
      init_name             = "init-container-for-secret-files"
      init_log_stream       = "ssm-file-downloader"
      secrets_volume        = "shared-volume"
      writable_mounts       = local.tdt_app_writable_mounts
      init_writable_mounts  = local.tdt_app_writable_mounts
      depends_on_fluent_bit = local.tdt_fluent_bit
    }],
    [
      for s in local.tdt.sidecars : {
        name               = s.name
        image              = s.image
        essential          = s.essential
        is_app             = false
        port               = s.port
        additional_ports   = s.additional_ports
        app_protocol       = s.app_protocol
        command            = s.command
        entrypoint         = s.entrypoint
        stop_timeout       = s.stop_timeout
        envs               = s.envs
        secrets            = s.secrets
        secrets_envs       = s.secrets_envs
        secrets_value_from = s.secrets_value_from
        secret_files       = s.secret_files
        secrets_files_path = s.secrets_files_path
        readonly           = s.readonly_root_filesystem != null ? s.readonly_root_filesystem : local.tdt.readonly_root_filesystem
        health_check       = s.health_check
        linux_parameters   = s.linux_parameters
        cpu                = s.cpu
        memory             = s.memory
        memory_reservation = s.memory_reservation
        firelens           = false
        log_stream_prefix  = s.log_stream_prefix != null ? s.log_stream_prefix : s.name
        main_port_name     = s.port != null ? "${s.name}-${s.port}-tcp" : s.name
        init_name          = "${s.name}-secret-init"
        init_log_stream    = "${s.name}-secret-init"
        secrets_volume     = "${s.name}-secrets"
        writable_mounts = [
          for d in s.writable_dirs : {
            sourceVolume  = "${s.name}-writable-${replace(trim(d, "/"), "/", "-")}"
            containerPath = d
          }
        ]
        init_writable_mounts  = []
        depends_on_fluent_bit = false
      } if s.enabled
    ],
  )

  tdt_built = [
    for s in local.tdt_specs : {
      init = [
        for files in [s.secret_files] : {
          for k, v in {
            name        = s.init_name
            image       = "public.ecr.aws/aws-cli/aws-cli:latest"
            essential   = false
            entryPoint  = ["/bin/sh"]
            command     = ["-c", local.tdt_secret_files_script[s.secrets_files_path]]
            environment = [{ name = "SECRET_FILES", value = join(",", files) }, { name = "AWS_REGION", value = local.tdt_region }]
            mountPoints = concat(
              [{ sourceVolume = s.secrets_volume, containerPath = s.secrets_files_path }],
              s.init_writable_mounts,
            )
            logConfiguration       = { logDriver = "awslogs", options = merge(local.tdt_log_options, { "awslogs-stream-prefix" = s.init_log_stream }) }
            readonlyRootFilesystem = s.readonly
          } : k => v if v != null
        } if length(files) > 0
      ]

      container = {
        for k, v in {
          name        = s.name
          image       = s.image
          essential   = s.essential
          environment = [for name, value in s.envs : { name = name, value = value }]
          command     = s.command
          entryPoint  = s.entrypoint
          secrets = concat(
            [for name, arn in s.secrets : { name = name, valueFrom = "${arn}:${name}::" }],
            flatten([for group in s.secrets_envs : [for key in group.values : { name = key, valueFrom = "${group.id}:${key}::" }]]),
            [for name, value_from in s.secrets_value_from : { name = name, valueFrom = value_from }],
          )
          stopTimeout = s.stop_timeout
          logConfiguration = {
            logDriver = s.firelens ? "awsfirelens" : "awslogs"
            options   = { for k, v in merge(local.tdt_log_options, { "awslogs-stream-prefix" = s.log_stream_prefix }) : k => v if !s.firelens }
          }
          healthCheck = try(s.health_check.command, null) == null ? null : (s.health_check.command == "" ? null : {
            command     = ["CMD-SHELL", s.health_check.command]
            interval    = s.health_check.interval
            timeout     = s.health_check.timeout
            retries     = s.health_check.retries
            startPeriod = s.health_check.start_period
          })
          portMappings = concat(
            [
              for port in [s.port] : {
                for k, v in {
                  name          = s.main_port_name
                  containerPort = port
                  hostPort      = local.tdt_bridge ? 0 : port
                  protocol      = "tcp"
                  appProtocol   = s.app_protocol != "tcp" ? s.app_protocol : null
                } : k => v if v != null
              } if port != null && port != 0
            ],
            [
              for name, port in s.additional_ports : {
                for k, v in {
                  name          = name
                  containerPort = port
                  hostPort      = local.tdt_bridge ? 0 : port
                  protocol      = "tcp"
                  appProtocol   = s.app_protocol != "tcp" ? s.app_protocol : null
                } : k => v if v != null
              }
            ],
          )
          linuxParameters = s.linux_parameters == null ? null : {
            for k, v in {
              initProcessEnabled = s.linux_parameters.init_process_enabled
              capabilities = s.linux_parameters.capabilities == null ? null : {
                for k, v in {
                  add  = s.linux_parameters.capabilities.add
                  drop = s.linux_parameters.capabilities.drop
                } : k => v if length(v) > 0
              }
              tmpfs = [
                for m in s.linux_parameters.tmpfs : {
                  for k, v in {
                    containerPath = m.container_path
                    size          = m.size
                    mountOptions  = length(m.mount_options) > 0 ? m.mount_options : null
                  } : k => v if v != null
                }
              ]
              swappiness = s.linux_parameters.swappiness
              maxSwap    = s.linux_parameters.max_swap
              # Fargate rejects these two, so they are dropped there.
              sharedMemorySize = var.ecs_launch_type == "FARGATE" ? null : s.linux_parameters.shared_memory_size
              devices = [
                for d in s.linux_parameters.devices : {
                  hostPath      = d.host_path
                  containerPath = d.container_path != null ? d.container_path : d.host_path
                  permissions   = d.permissions
                } if var.ecs_launch_type != "FARGATE"
              ]
            } : k => v if v != null && !try(length(v) == 0, false)
          }
          cpu                    = s.cpu
          memory                 = s.memory
          memoryReservation      = s.memory_reservation
          readonlyRootFilesystem = s.readonly
          mountPoints = concat(
            [for files in [s.secret_files] : { sourceVolume = s.secrets_volume, containerPath = s.secrets_files_path } if length(files) > 0],
            s.writable_mounts,
          )
          dependsOn = concat(
            [for files in [s.secret_files] : { containerName = s.init_name, condition = "SUCCESS" } if length(files) > 0],
            [for enabled in [s.depends_on_fluent_bit] : { containerName = "fluent-bit", condition = "START" } if enabled],
          )
        } : k => v if v != null && !try(length(v) == 0, false)
      }
    }
  ]

  tdt_fluent_bit_containers = [
    for fb in [local.tdt.fluent_bit_collector] : {
      for k, v in {
        name      = "fluent-bit"
        image     = fb.image != null ? fb.image : "${local.tdt_ecr_registry}/${trimspace(fb.image_name)}"
        essential = true
        environment = [
          { name = "SERVICE_NAME", value = fb.service_name != null ? fb.service_name : var.ecs_service_name },
          { name = "ENV", value = var.ecs_cluster_name },
        ]
        healthCheck = {
          command     = ["CMD-SHELL", "curl -f http://127.0.0.1:2020/api/v1/health || exit 1"]
          interval    = 10
          timeout     = 5
          retries     = 3
          startPeriod = 5
        }
        logConfiguration = { logDriver = "awslogs", options = merge(local.tdt_log_options, { "awslogs-stream-prefix" = "fluentbit" }) }
        firelensConfiguration = {
          type = "fluentbit"
          options = {
            "config-file-type"        = "file"
            "config-file-value"       = "extra/${fb.extra_config}"
            "enable-ecs-log-metadata" = tostring(fb.ecs_log_metadata)
          }
        }
        readonlyRootFilesystem = local.tdt.readonly_root_filesystem
        mountPoints            = local.tdt_app_writable_mounts
      } : k => v if v != null && !try(length(v) == 0, false)
    } if local.tdt_fluent_bit
  ]

  tdt_otel_containers = [
    for otel in [local.tdt.otel_collector] : {
      for k, v in {
        name = "otel-collector"
        image = otel.image != null ? otel.image : (
          trimspace(otel.image_name) != "" ? "${local.tdt_ecr_registry}/${trimspace(otel.image_name)}" : "public.ecr.aws/aws-observability/aws-otel-collector:latest"
        )
        portMappings = [
          { name = "otel-collector-4317-tcp", containerPort = 4317, hostPort = 4317, protocol = "tcp", appProtocol = "grpc" },
          { name = "otel-collector-4318-tcp", containerPort = 4318, hostPort = 4318, protocol = "tcp" },
        ]
        essential        = true
        command          = local.tdt_otel_custom ? ["--config", "/conf/${trimspace(otel.extra_config) != "" ? trimspace(otel.extra_config) : "config.yaml"}"] : ["--config", "env:SSM_CONFIG"]
        logConfiguration = { logDriver = "awslogs", options = merge(local.tdt_log_options, { "awslogs-stream-prefix" = "otel-collector" }) }
        environment = concat(
          [{ name = "METRICS_PATH", value = otel.metrics_path }, { name = "METRICS_PORT", value = tostring(otel.metrics_port) }],
          [for custom in [local.tdt_otel_custom] : { name = "SERVICE_NAME", value = var.ecs_service_name } if custom],
        )
        secrets                = [for custom in [local.tdt_otel_custom] : { name = "SSM_CONFIG", valueFrom = trimspace(otel.ssm_name) } if !custom]
        readonlyRootFilesystem = local.tdt.readonly_root_filesystem
        mountPoints            = local.tdt_app_writable_mounts
      } : k => v if v != null && !try(length(v) == 0, false)
    } if local.tdt_otel
  ]

  tdt_generated_containers = concat(
    local.tdt_built[0].init,
    [local.tdt_built[0].container],
    local.tdt_fluent_bit_containers,
    local.tdt_otel_containers,
    flatten([for b in slice(local.tdt_built, 1, length(local.tdt_built)) : concat(b.init, [b.container])]),
  )

  tdt_container_definitions = concat(
    [for c in local.tdt_generated_containers : merge(c, try(local.tdt.container_overrides[c.name], {}))],
    try([for c in local.tdt.container_definitions : c], []),
  )

  tdt_container_names = [for c in local.tdt_container_definitions : try(c.name, "")]

  tdt_port_mapping_names = flatten([
    for c in local.tdt_generated_containers : [for p in try(c.portMappings, []) : p.name]
  ])

  tdt_volumes = concat(
    [for files in [local.tdt.secret_files] : { name = "shared-volume", host_path = null, efs_volume_configuration = null } if length(files) > 0],
    [for d in local.tdt.writable_dirs : { name = "writable-${replace(trim(d, "/"), "/", "-")}", host_path = null, efs_volume_configuration = null }],
    flatten([
      for s in local.tdt.sidecars : concat(
        [for files in [s.secret_files] : { name = "${s.name}-secrets", host_path = null, efs_volume_configuration = null } if length(files) > 0],
        [for d in s.writable_dirs : { name = "${s.name}-writable-${replace(trim(d, "/"), "/", "-")}", host_path = null, efs_volume_configuration = null }],
      ) if s.enabled
    ]),
    local.tdt.volumes,
  )

  # Downloads each secret in SECRET_FILES to the mount path, as text or, failing
  # that, as binary. Keyed by mount path because a path is the only input.
  tdt_secret_files_script = {
    for path in distinct([for s in local.tdt_specs : s.secrets_files_path]) : path => join("", [
      "for secret in $${SECRET_FILES//,/ }; do ",
      "  echo \"Fetching $secret...\"; ",
      "  echo \"Debug: AWS_REGION=$AWS_REGION, SECRET_PATH=${path}\"; ",
      "  SECRET_VALUE=$(aws secretsmanager get-secret-value --secret-id $secret --region $AWS_REGION --query SecretString --output text 2>/dev/null); ",
      "  STRING_RESULT=$?; ",
      "  if [ $STRING_RESULT -eq 0 ] && [ -n \"$SECRET_VALUE\" ] && [ \"$SECRET_VALUE\" != \"null\" ] && [ \"$SECRET_VALUE\" != \"none\" ] && [ \"$SECRET_VALUE\" != \"None\" ]; then ",
      "    echo \"Found text secret, saving to ${path}/$secret\"; ",
      "    echo \"$SECRET_VALUE\" > ${path}/$secret; ",
      "  else ",
      "    echo \"Text retrieval failed or returned null, trying binary retrieval...\"; ",
      "    aws secretsmanager get-secret-value --secret-id $secret --region $AWS_REGION --query SecretBinary --output text | base64 -d > ${path}/$secret 2>/dev/null; ",
      "    BINARY_RESULT=$?; ",
      "    if [ $BINARY_RESULT -eq 0 ] && [ -s ${path}/$secret ]; then ",
      "      echo \"Found binary secret, saved to ${path}/$secret\"; ",
      "    else ",
      "      echo \"❌ Failed to retrieve $secret as either text or binary\" >&2; ",
      "      echo \"Text result: $STRING_RESULT, Binary result: $BINARY_RESULT\" >&2; ",
      "      exit 1; ",
      "    fi; ",
      "  fi; ",
      "  echo \"✅ Successfully saved $secret to ${path}/$secret (size: $(stat -c%s ${path}/$secret 2>/dev/null || wc -c < ${path}/$secret))\"; ",
      "done",
    ])
  }
}
