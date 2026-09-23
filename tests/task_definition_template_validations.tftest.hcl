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

# Each check turns a mistake that would otherwise surface at registration, at
# deploy or at task start into a plan error. Every failing case has a passing
# neighbour, so a check that rejects everything cannot pass.

# Load balancers and Service Connect address the template's ports.

run "alb_port_mapped" {
  command = plan
  variables {
    application_load_balancer = {
      enabled        = true
      container_port = 8080
      listener_arn   = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/lb/abc/def"
    }
    task_definition_template = { enabled = true, cpu = 256, memory = 512, port = 8080 }
  }
}

run "alb_port_not_mapped" {
  command = plan
  variables {
    application_load_balancer = {
      enabled        = true
      container_port = 80
      listener_arn   = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/lb/abc/def"
    }
    task_definition_template = { enabled = true, cpu = 256, memory = 512, port = 8080 }
  }
  expect_failures = [aws_ecs_task_definition.template]
}

run "additional_lb_port_in_additional_ports" {
  command = plan
  variables {
    additional_load_balancers = [{
      enabled        = true
      container_port = 9090
      listener_arn   = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/lb/abc/def"
    }]
    task_definition_template = { enabled = true, cpu = 256, memory = 512, port = 8080, additional_ports = { admin = 9090 } }
  }
}

run "additional_lb_port_not_mapped" {
  command = plan
  variables {
    additional_load_balancers = [{
      enabled        = true
      container_port = 9090
      listener_arn   = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/lb/abc/def"
    }]
    task_definition_template = { enabled = true, cpu = 256, memory = 512, port = 8080 }
  }
  expect_failures = [aws_ecs_task_definition.template]
}

run "service_connect_ports_present" {
  command = plan
  variables {
    service_connect = {
      enabled          = true, type = "client-server", name = "api", port = 8080
      additional_ports = [{ name = "admin", port = 9090 }]
    }
    task_definition_template = { enabled = true, cpu = 256, memory = 512, port = 8080, additional_ports = { admin = 9090 } }
  }
}

run "service_connect_without_template_port" {
  command = plan
  variables {
    service_connect          = { enabled = true, type = "client-server", name = "api", port = 8080 }
    task_definition_template = { enabled = true, cpu = 256, memory = 512 }
  }
  expect_failures = [aws_ecs_task_definition.template]
}

run "service_connect_additional_port_missing" {
  command = plan
  variables {
    service_connect = {
      enabled          = true, type = "client-server", name = "api", port = 8080
      additional_ports = [{ name = "admin", port = 9090 }]
    }
    task_definition_template = { enabled = true, cpu = 256, memory = 512, port = 8080 }
  }
  expect_failures = [aws_ecs_task_definition.template]
}

run "service_connect_client_only_needs_no_port" {
  command = plan
  variables {
    service_connect          = { enabled = true, type = "client-only" }
    task_definition_template = { enabled = true, cpu = 256, memory = 512 }
  }
}

run "service_connect_tcp_matches_tcp_port" {
  command = plan
  variables {
    service_connect          = { enabled = true, type = "client-server", name = "db", port = 5432, appProtocol = "tcp" }
    task_definition_template = { enabled = true, cpu = 256, memory = 512, port = 5432, app_protocol = "tcp" }
  }
}

run "service_connect_tcp_with_http_port" {
  command = plan
  variables {
    service_connect          = { enabled = true, type = "client-server", name = "db", port = 5432, appProtocol = "tcp" }
    task_definition_template = { enabled = true, cpu = 256, memory = 512, port = 5432 }
  }
  expect_failures = [aws_ecs_task_definition.template]
}

# Container ports and volume names.

run "duplicate_container_port_awsvpc" {
  command = plan
  variables {
    task_definition_template = {
      enabled  = true, cpu = 256, memory = 512, port = 8080
      sidecars = [{ name = "proxy", image = "envoy", port = 8080 }]
    }
  }
  expect_failures = [aws_ecs_task_definition.template]
}

run "duplicate_container_port_bridge" {
  command = plan
  variables {
    ecs_launch_type = "EC2"
    network_mode    = "bridge"
    task_definition_template = {
      enabled  = true, cpu = 256, memory = 512, port = 8080
      sidecars = [{ name = "proxy", image = "envoy", port = 8080 }]
    }
  }
}

run "writable_dir_with_dot" {
  command = plan
  variables {
    task_definition_template = { enabled = true, cpu = 256, memory = 512, writable_dirs = ["/var/cache.d"] }
  }
  expect_failures = [aws_ecs_task_definition.template]
}

run "writable_dir_nested" {
  command = plan
  variables {
    task_definition_template = { enabled = true, cpu = 256, memory = 512, writable_dirs = ["/var/cache/app_1"] }
  }
}

# Secrets.

run "secret_files_without_task_role" {
  command = plan
  variables {
    task_role                = {}
    task_definition_template = { enabled = true, cpu = 256, memory = 512, secret_files = ["tls-cert"] }
  }
  expect_failures = [var.task_definition_template]
}

run "sidecar_secret_files_without_task_role" {
  command = plan
  variables {
    task_role = {}
    task_definition_template = {
      enabled  = true, cpu = 256, memory = 512
      sidecars = [{ name = "agent", image = "agent", secret_files = ["agent-key"] }]
    }
  }
  expect_failures = [var.task_definition_template]
}

run "secret_files_with_task_role_arn" {
  command = plan
  variables {
    task_role                = { arn = "arn:aws:iam::123456789012:role/task" }
    task_definition_template = { enabled = true, cpu = 256, memory = 512, secret_files = ["tls-cert"] }
  }
}

run "secret_by_name" {
  command = plan
  variables {
    task_definition_template = { enabled = true, cpu = 256, memory = 512, secrets = { DB_PASSWORD = "prod/db" } }
  }
  expect_failures = [var.task_definition_template]
}

run "sidecar_secrets_envs_by_name" {
  command = plan
  variables {
    task_definition_template = {
      enabled  = true, cpu = 256, memory = 512
      sidecars = [{ name = "agent", image = "agent", secrets_envs = [{ id = "prod/agent", values = ["TOKEN"] }] }]
    }
  }
  expect_failures = [var.task_definition_template]
}

run "secret_value_from_by_name" {
  command = plan
  variables {
    task_definition_template = { enabled = true, cpu = 256, memory = 512, secrets_value_from = { API_KEY = "/api/key" } }
  }
}

# Fargate sizing.

run "fargate_invalid_cpu_memory" {
  command = plan
  variables {
    task_definition_template = { enabled = true, cpu = 256, memory = 4096 }
  }
  expect_failures = [var.task_definition_template]
}

run "fargate_largest_size" {
  command = plan
  variables {
    task_definition_template = { enabled = true, cpu = 16384, memory = 122880 }
  }
}

run "ec2_any_cpu_memory" {
  command = plan
  variables {
    ecs_launch_type          = "EC2"
    task_definition_template = { enabled = true, cpu = 256, memory = 4096 }
  }
}

run "fargate_sidecars_exceed_task_memory" {
  command = plan
  variables {
    task_definition_template = {
      enabled  = true, cpu = 1024, memory = 2048
      sidecars = [{ name = "a", image = "a", memory = 1024 }, { name = "b", image = "b", memory = 1024 }]
    }
  }
  expect_failures = [var.task_definition_template]
}

run "fargate_sidecars_leave_room" {
  command = plan
  variables {
    task_definition_template = {
      enabled = true, cpu = 1024, memory = 2048
      sidecars = [
        { name = "a", image = "a", cpu = 256, memory = 1024 },
        { name = "b", image = "b", cpu = 1024, memory = 1024, enabled = false },
      ]
    }
  }
}

run "ec2_ephemeral_storage" {
  command = plan
  variables {
    ecs_launch_type          = "EC2"
    task_definition_template = { enabled = true, cpu = 256, memory = 512, ephemeral_storage_gib = 30 }
  }
  expect_failures = [var.task_definition_template]
}

run "fargate_ephemeral_storage_too_small" {
  command = plan
  variables {
    task_definition_template = { enabled = true, cpu = 256, memory = 512, ephemeral_storage_gib = 20 }
  }
  expect_failures = [var.task_definition_template]
}
