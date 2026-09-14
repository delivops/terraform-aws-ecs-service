# Every task setting lives in Terraform; the deploy pipeline only picks the
# image. The module keeps the "<cluster>_template-app-template" family up to
# date and publishes its name to
# /ecs/<cluster>/template-app/task-definition-template. A deploy copies the
# family's latest revision, replaces the image of the "app" container and
# registers it into the service's own family.
#
# The "app" image below is a placeholder that never runs.

module "template_ecs_service" {
  source             = "../"
  ecs_cluster_name   = var.cluster_name
  ecs_service_name   = "template-app"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  task_role = {
    create = true
  }

  execution_role = {
    create = true
    # The app reads a secret from SSM, which AmazonECSTaskExecutionRolePolicy
    # does not cover.
    inline_policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = ["ssm:GetParameters"]
          Resource = "arn:aws:ssm:*:*:parameter/template-app/*"
        }
      ]
    })
  }

  task_definition_template = {
    enabled          = true
    cpu              = 512
    memory           = 1024
    cpu_architecture = "ARM64"

    container_definitions = [
      {
        name      = "app"
        image     = "template-app:template"
        essential = true
        portMappings = [
          { name = "default", containerPort = 8080, hostPort = 8080, protocol = "tcp" }
        ]
        environment = [
          { name = "OTEL_EXPORTER_OTLP_ENDPOINT", value = "http://localhost:4317" },
        ]
        secrets = [
          { name = "DATABASE_URL", valueFrom = "/template-app/database-url" },
        ]
        healthCheck = {
          command     = ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
          interval    = 30
          timeout     = 5
          retries     = 3
          startPeriod = 10
        }
        dependsOn = [
          { containerName = "otel-collector", condition = "START" }
        ]
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = "/ecs/${var.cluster_name}/template-app"
            awslogs-region        = var.region
            awslogs-stream-prefix = "app"
          }
        }
      },
      {
        name      = "otel-collector"
        image     = "otel/opentelemetry-collector-contrib:0.110.0"
        essential = false
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = "/ecs/${var.cluster_name}/template-app"
            awslogs-region        = var.region
            awslogs-stream-prefix = "otel"
          }
        }
      },
    ]
  }
}
