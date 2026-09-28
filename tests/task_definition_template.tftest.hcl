# Mocked AWS: the cluster ARN is the only source of partition, region and
# account for the template, so the caller identity deliberately differs.
mock_provider "aws" {
  mock_data "aws_ecs_cluster" {
    defaults = { cluster_name = "prod", arn = "arn:aws:ecs:us-east-1:123456789012:cluster/prod" }
  }
  mock_data "aws_region" {
    defaults = { id = "us-east-1", name = "us-east-1", region = "us-east-1" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "999999999999" }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::123456789012:role/mock" }
  }
  mock_resource "aws_ecs_task_definition" {
    defaults = { arn = "arn:aws:ecs:us-east-1:123456789012:task-definition/prod_api:1" }
  }
  mock_resource "aws_cloudwatch_log_group" {
    defaults = { arn = "arn:aws:logs:us-east-1:123456789012:log-group:/ecs/prod/api" }
  }
}

variables {
  ecs_cluster_name   = "prod"
  ecs_service_name   = "api"
  vpc_id             = "vpc-1"
  subnet_ids         = ["subnet-1"]
  security_group_ids = ["sg-1"]
  execution_role     = { create = true }
  task_role          = { create = true }
}

run "disabled_defaults" {
  command = plan
  variables {
    execution_role = {}
    task_role      = {}
  }
  assert {
    condition     = length(aws_ecs_task_definition.template) == 0 && length(aws_ssm_parameter.task_definition_template) == 0
    error_message = "the template is opt-in"
  }
}

run "disabled_ec2_bridge" {
  command = plan
  variables {
    ecs_launch_type = "EC2"
    network_mode    = "bridge"
  }
  assert {
    condition     = length(aws_ecs_task_definition.template) == 0
    error_message = "the template is opt-in"
  }
}

run "fargate_full" {
  command = apply
  variables {
    task_definition_template = {
      enabled                  = true
      cpu                      = 1024
      memory                   = 2048
      cpu_architecture         = "ARM64"
      ephemeral_storage_gib    = 30
      replica_count            = 2
      port                     = 8080
      additional_ports         = { metrics = 9090 }
      envs                     = { LOG_LEVEL = "info" }
      secrets                  = { DB_PASSWORD = "arn:aws:secretsmanager:us-east-1:123456789012:secret:db-AbCdEf" }
      secrets_value_from       = { API_KEY = "arn:aws:ssm:us-east-1:123456789012:parameter/api/key" }
      secret_files             = ["tls-cert"]
      readonly_root_filesystem = true
      writable_dirs            = ["/tmp"]
      health_check             = { command = "curl -f http://localhost:8080/health || exit 1" }
      linux_parameters         = { init_process_enabled = true, tmpfs = [{ container_path = "/run", size = 64 }] }
      otel_collector           = {}
      fluent_bit_collector     = { image_name = "fluent-bit:latest" }
      sidecars = [{
        name          = "cache", image = "redis:7", port = 6379, memory_reservation = 128,
        secrets_envs  = [{ id = "arn:aws:secretsmanager:us-east-1:123456789012:secret:cache-AbCdEf", values = ["REDIS_PASSWORD"] }],
        writable_dirs = ["/data"]
      }]
      volumes             = [{ name = "shared", efs_volume_configuration = { file_system_id = "fs-1", transit_encryption = "ENABLED", authorization_config = { access_point_id = "fsap-1", iam = "ENABLED" } } }]
      container_overrides = { app = { ulimits = [{ name = "nofile", softLimit = 65536, hardLimit = 65536 }] } }
    }
  }

  assert {
    condition     = length(aws_ecs_task_definition.template[0].runtime_platform) == 1 && length(aws_ecs_task_definition.template[0].volume) == 4
    error_message = "fargate template should declare runtime_platform and 4 volumes"
  }
  assert {
    condition     = aws_ssm_parameter.task_definition_template_replica_count[0].value == "2" && aws_ssm_parameter.task_definition_template_replica_count[0].name == "/ecs/prod/api/replica-count"
    error_message = "replica count parameter"
  }
  assert {
    condition     = [for c in jsondecode(aws_ecs_task_definition.template[0].container_definitions) : c.name] == ["init-container-for-secret-files", "app", "fluent-bit", "otel-collector", "cache"]
    error_message = "container order"
  }
  assert {
    condition     = jsondecode(aws_ecs_task_definition.template[0].container_definitions)[1].logConfiguration.logDriver == "awsfirelens" && jsondecode(aws_ecs_task_definition.template[0].container_definitions)[2].image == "123456789012.dkr.ecr.us-east-1.amazonaws.com/fluent-bit:latest"
    error_message = "firelens routing / ECR registry prefix"
  }
  assert {
    condition     = !contains(keys(jsondecode(aws_ecs_task_definition.template[0].container_definitions)[1].logConfiguration), "options")
    error_message = "a FireLens-routed container carries no options map"
  }
  assert {
    condition     = aws_ssm_parameter.task_definition_template[0].name == "/ecs/prod/api/task-definition-template" && aws_ssm_parameter.task_definition_template[0].value == "prod_api-template"
    error_message = "template family parameter"
  }
  assert {
    condition     = jsondecode(aws_ecs_task_definition.template[0].container_definitions)[4].logConfiguration.options["awslogs-group"] == "/ecs/prod/api" && jsondecode(aws_ecs_task_definition.template[0].container_definitions)[4].logConfiguration.options["awslogs-region"] == "us-east-1"
    error_message = "sidecar log group/region"
  }
}

run "ec2_bridge_enabled" {
  command = apply
  variables {
    ecs_launch_type = "EC2"
    network_mode    = "bridge"
    task_definition_template = {
      enabled          = true
      cpu              = 512
      memory           = 1024
      port             = 8080
      linux_parameters = { shared_memory_size = 256, devices = [{ host_path = "/dev/nvidia0" }] }
      volumes          = [{ name = "host", host_path = "/var/data" }]
    }
  }
  assert {
    condition     = length(aws_ecs_task_definition.template[0].runtime_platform) == 0
    error_message = "EC2 template must not declare runtime_platform"
  }
  assert {
    condition     = jsondecode(aws_ecs_task_definition.template[0].container_definitions)[0].portMappings[0].hostPort == 0 && jsondecode(aws_ecs_task_definition.template[0].container_definitions)[0].linuxParameters.sharedMemorySize == 256
    error_message = "bridge dynamic host port / EC2-only linux parameters"
  }
  assert {
    condition     = length(aws_ssm_parameter.task_definition_template_replica_count) == 0
    error_message = "no replica count parameter when unset"
  }
}
