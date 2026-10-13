# Mocked AWS, as in the task_definition_template suites.
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

run "grace_period_unset_by_default" {
  command = plan

  assert {
    condition     = aws_ecs_service.ecs_service.health_check_grace_period_seconds == null
    error_message = "health_check_grace_period_seconds should stay unset when the input is null."
  }
}

run "grace_period_passed_through" {
  command = plan

  variables {
    health_check_grace_period_seconds = 120
  }

  assert {
    condition     = aws_ecs_service.ecs_service.health_check_grace_period_seconds == 120
    error_message = "health_check_grace_period_seconds should reach the service."
  }
}

run "grace_period_zero_allowed" {
  command = plan

  variables {
    health_check_grace_period_seconds = 0
  }
}

run "grace_period_negative_rejected" {
  command = plan

  variables {
    health_check_grace_period_seconds = -1
  }

  expect_failures = [var.health_check_grace_period_seconds]
}

run "grace_period_fractional_rejected" {
  command = plan

  variables {
    health_check_grace_period_seconds = 1.5
  }

  expect_failures = [var.health_check_grace_period_seconds]
}

run "grace_period_over_max_rejected" {
  command = plan

  variables {
    health_check_grace_period_seconds = 2147483648
  }

  expect_failures = [var.health_check_grace_period_seconds]
}
