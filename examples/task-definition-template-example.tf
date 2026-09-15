# Every task setting lives in Terraform; the deploy pipeline only picks the
# image. The module keeps the "<cluster>_template-app-template" family up to
# date, publishes its name to
# /ecs/<cluster>/template-app/task-definition-template and the replica count to
# /ecs/<cluster>/template-app/replica-count. A deploy copies the family's latest
# revision, replaces the image of the "app" container, registers it into the
# service's own family and sets the desired count.

module "template_ecs_service" {
  source             = "../"
  ecs_cluster_name   = var.cluster_name
  ecs_service_name   = "template-app"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  # A placeholder: the pipeline replaces it with the build it deploys.
  container_image = "template-app:template"

  task_role = {
    create = true
    # secret_files are downloaded by an init container running inside the task,
    # so they are read with the task role, not the execution role.
    inline_policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = ["secretsmanager:GetSecretValue"]
          Resource = ["arn:aws:secretsmanager:*:*:secret:template-app-tls-cert-*"]
        }
      ]
    })
  }

  execution_role = {
    create = true
    # AmazonECSTaskExecutionRolePolicy does not cover secrets and parameters
    # injected as environment variables.
    inline_policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = ["secretsmanager:GetSecretValue"]
          Resource = [var.database_secret_arn]
        },
        {
          Effect   = "Allow"
          Action   = ["ssm:GetParameters"]
          Resource = ["arn:aws:ssm:*:*:parameter/template-app/*"]
        }
      ]
    })
  }

  task_definition_template = {
    enabled                  = true
    cpu                      = 1024
    memory                   = 2048
    cpu_architecture         = "ARM64"
    replica_count            = 2
    readonly_root_filesystem = true
    writable_dirs            = ["/tmp"]

    port             = 8080
    additional_ports = { metrics = 9090 }
    envs = {
      LOG_LEVEL                   = "info"
      OTEL_EXPORTER_OTLP_ENDPOINT = "http://localhost:4317"
    }
    # Each env var reads the JSON key of the same name from the secret.
    secrets_envs = [
      { id = var.database_secret_arn, values = ["DB_HOST", "DB_PASSWORD"] },
    ]
    secrets_value_from = {
      API_KEY = "/template-app/api-key"
    }
    secret_files = ["template-app-tls-cert"]
    health_check = {
      command = "curl -f http://localhost:8080/health || exit 1"
    }

    otel_collector = {}

    sidecars = [
      {
        name               = "cache"
        image              = "public.ecr.aws/docker/library/redis:7"
        port               = 6379
        memory_reservation = 128
        writable_dirs      = ["/data"]
      },
    ]

    container_overrides = {
      app = { ulimits = [{ name = "nofile", softLimit = 65536, hardLimit = 65536 }] }
    }
  }
}
