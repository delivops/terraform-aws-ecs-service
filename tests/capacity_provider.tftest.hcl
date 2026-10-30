# Capacity provider strategies: the string shorthand, the list, the cluster default, and each validation. Mocked AWS.
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
  mock_data "aws_lb_listener" {
    defaults = { load_balancer_arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/main/1" }
  }
  mock_data "aws_lb" {
    defaults = { arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/main/1", dns_name = "main.example", zone_id = "Z1" }
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
  mock_resource "aws_alb_target_group" {
    defaults = { arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/api/1" }
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

run "launch_type_only_is_unchanged" {
  command = plan
  assert {
    condition     = aws_ecs_service.ecs_service.launch_type == "FARGATE"
    error_message = "launch_type should be FARGATE."
  }
  assert {
    condition     = length(aws_ecs_service.ecs_service.capacity_provider_strategy) == 0
    error_message = "Unexpected capacity_provider_strategy blocks."
  }
  assert {
    condition     = aws_ecs_task_definition.task_definition.requires_compatibilities == toset(["FARGATE"])
    error_message = "Task definition should require FARGATE."
  }
  assert {
    condition     = aws_ecs_service.ecs_service.platform_version == "LATEST"
    error_message = "platform_version should be LATEST."
  }
}

run "ec2_launch_type_only_is_unchanged" {
  command = plan
  variables {
    ecs_launch_type = "EC2"
    network_mode    = "bridge"
  }
  assert {
    condition     = aws_ecs_service.ecs_service.launch_type == "EC2"
    error_message = "launch_type should be EC2."
  }
  assert {
    condition     = length(aws_ecs_service.ecs_service.capacity_provider_strategy) == 0
    error_message = "Unexpected capacity_provider_strategy blocks."
  }
  assert {
    condition     = aws_ecs_task_definition.task_definition.requires_compatibilities == toset(["EC2"])
    error_message = "Task definition should require EC2."
  }
}

run "string_is_a_single_base_0_weight_1_entry" {
  command = plan
  variables {
    capacity_provider_strategy = "FARGATE_SPOT"
  }
  assert {
    condition     = toset([for s in aws_ecs_service.ecs_service.capacity_provider_strategy : { p = s.capacity_provider, b = s.base, w = s.weight }]) == toset([{ p = "FARGATE_SPOT", b = 0, w = 1 }])
    error_message = "Unexpected capacity_provider_strategy blocks."
  }
  assert {
    condition     = aws_ecs_task_definition.task_definition.requires_compatibilities == toset(["FARGATE"])
    error_message = "Task definition should require FARGATE."
  }
  assert {
    condition     = aws_ecs_service.ecs_service.platform_version == "LATEST"
    error_message = "platform_version should be LATEST."
  }
}

run "string_with_asg_provider_on_ec2" {
  command = plan
  variables {
    ecs_launch_type            = "EC2"
    network_mode               = "bridge"
    capacity_provider_strategy = "my-asg"
  }
  assert {
    condition     = toset([for s in aws_ecs_service.ecs_service.capacity_provider_strategy : { p = s.capacity_provider, b = s.base, w = s.weight }]) == toset([{ p = "my-asg", b = 0, w = 1 }])
    error_message = "Unexpected capacity_provider_strategy blocks."
  }
  assert {
    condition     = aws_ecs_task_definition.task_definition.requires_compatibilities == toset(["EC2"])
    error_message = "Task definition should require EC2."
  }
}

run "floor_plus_spot" {
  command = plan
  variables {
    capacity_provider_strategies = [
      { capacity_provider = "FARGATE", base = 2, weight = 1 },
      { capacity_provider = "FARGATE_SPOT", weight = 4 },
    ]
  }
  assert {
    condition     = toset([for s in aws_ecs_service.ecs_service.capacity_provider_strategy : { p = s.capacity_provider, b = s.base, w = s.weight }]) == toset([{ p = "FARGATE", b = 2, w = 1 }, { p = "FARGATE_SPOT", b = 0, w = 4 }])
    error_message = "Unexpected capacity_provider_strategy blocks."
  }
  assert {
    condition     = aws_ecs_task_definition.task_definition.requires_compatibilities == toset(["FARGATE"])
    error_message = "Task definition should require FARGATE."
  }
  assert {
    condition     = aws_ecs_service.ecs_service.platform_version == "LATEST"
    error_message = "platform_version should be LATEST."
  }
}

run "spot_only" {
  command = plan
  variables {
    capacity_provider_strategies = [{ capacity_provider = "FARGATE_SPOT" }]
  }
  assert {
    condition     = toset([for s in aws_ecs_service.ecs_service.capacity_provider_strategy : { p = s.capacity_provider, b = s.base, w = s.weight }]) == toset([{ p = "FARGATE_SPOT", b = 0, w = 1 }])
    error_message = "Unexpected capacity_provider_strategy blocks."
  }
  assert {
    condition     = aws_ecs_task_definition.task_definition.requires_compatibilities == toset(["FARGATE"])
    error_message = "Task definition should require FARGATE."
  }
  assert {
    condition     = aws_ecs_service.ecs_service.platform_version == "LATEST"
    error_message = "platform_version should be LATEST."
  }
}

run "fargate_list_with_ec2_launch_type_is_rejected" {
  command = plan
  variables {
    ecs_launch_type              = "EC2"
    network_mode                 = "bridge"
    capacity_provider_strategies = [{ capacity_provider = "FARGATE_SPOT" }]
  }
  expect_failures = [var.capacity_provider_strategies]
}

run "asg_list_on_ec2" {
  command = plan
  variables {
    ecs_launch_type = "EC2"
    network_mode    = "bridge"
    capacity_provider_strategies = [
      { capacity_provider = "asg-a", base = 1 },
      { capacity_provider = "asg-b", weight = 3 },
    ]
  }
  assert {
    condition     = toset([for s in aws_ecs_service.ecs_service.capacity_provider_strategy : { p = s.capacity_provider, b = s.base, w = s.weight }]) == toset([{ p = "asg-a", b = 1, w = 1 }, { p = "asg-b", b = 0, w = 3 }])
    error_message = "Unexpected capacity_provider_strategy blocks."
  }
  assert {
    condition     = aws_ecs_task_definition.task_definition.requires_compatibilities == toset(["EC2"])
    error_message = "Task definition should require EC2."
  }
}

run "cluster_default" {
  command = plan
  variables {
    use_cluster_default_capacity_provider_strategy = true
  }
  assert {
    condition     = length(aws_ecs_service.ecs_service.capacity_provider_strategy) == 0
    error_message = "Unexpected capacity_provider_strategy blocks."
  }
  assert {
    condition     = aws_ecs_task_definition.task_definition.requires_compatibilities == toset(["FARGATE"])
    error_message = "Task definition should require FARGATE."
  }
  assert {
    condition     = aws_ecs_service.ecs_service.platform_version == "LATEST"
    error_message = "platform_version should be LATEST."
  }
}

run "string_and_list_are_exclusive" {
  command = plan
  variables {
    capacity_provider_strategy   = "FARGATE"
    capacity_provider_strategies = [{ capacity_provider = "FARGATE_SPOT" }]
  }
  expect_failures = [var.capacity_provider_strategies]
}

run "string_and_cluster_default_are_exclusive" {
  command = plan
  variables {
    capacity_provider_strategy                     = "FARGATE"
    use_cluster_default_capacity_provider_strategy = true
  }
  expect_failures = [var.capacity_provider_strategies]
}

run "list_and_cluster_default_are_exclusive" {
  command = plan
  variables {
    capacity_provider_strategies                   = [{ capacity_provider = "FARGATE" }]
    use_cluster_default_capacity_provider_strategy = true
  }
  expect_failures = [var.capacity_provider_strategies]
}

run "two_base_entries" {
  command = plan
  variables {
    capacity_provider_strategies = [
      { capacity_provider = "FARGATE", base = 1 },
      { capacity_provider = "FARGATE_SPOT", base = 1 },
    ]
  }
  expect_failures = [var.capacity_provider_strategies]
}

run "base_above_limit" {
  command = plan
  variables {
    capacity_provider_strategies = [{ capacity_provider = "FARGATE", base = 100001 }]
  }
  expect_failures = [var.capacity_provider_strategies]
}

run "base_negative" {
  command = plan
  variables {
    capacity_provider_strategies = [{ capacity_provider = "FARGATE", base = -1 }]
  }
  expect_failures = [var.capacity_provider_strategies]
}

run "weight_above_limit" {
  command = plan
  variables {
    capacity_provider_strategies = [{ capacity_provider = "FARGATE", weight = 1001 }]
  }
  expect_failures = [var.capacity_provider_strategies]
}

run "all_weights_zero" {
  command = plan
  variables {
    capacity_provider_strategies = [
      { capacity_provider = "FARGATE", base = 1, weight = 0 },
      { capacity_provider = "FARGATE_SPOT", weight = 0 },
    ]
  }
  expect_failures = [var.capacity_provider_strategies]
}

run "fargate_mixed_with_asg" {
  command = plan
  variables {
    ecs_launch_type = "EC2"
    network_mode    = "bridge"
    capacity_provider_strategies = [
      { capacity_provider = "FARGATE" },
      { capacity_provider = "my-asg" },
    ]
  }
  expect_failures = [var.capacity_provider_strategies]
}

run "asg_list_needs_ec2_launch_type" {
  command = plan
  variables {
    capacity_provider_strategies = [{ capacity_provider = "my-asg" }]
  }
  expect_failures = [var.capacity_provider_strategies]
}

run "duplicate_provider" {
  command = plan
  variables {
    capacity_provider_strategies = [
      { capacity_provider = "FARGATE" },
      { capacity_provider = "FARGATE", weight = 2 },
    ]
  }
  expect_failures = [var.capacity_provider_strategies]
}

run "empty_provider_name" {
  command = plan
  variables {
    capacity_provider_strategies = [{ capacity_provider = "" }]
  }
  expect_failures = [var.capacity_provider_strategies]
}

run "force_new_deployment_is_passed_through" {
  command = plan
  variables {
    force_new_deployment         = true
    capacity_provider_strategies = [{ capacity_provider = "FARGATE_SPOT" }]
  }
  assert {
    condition     = aws_ecs_service.ecs_service.force_new_deployment == true
    error_message = "force_new_deployment = true should reach the service."
  }
}

run "force_new_deployment_off_leaves_the_attribute_unset" {
  command = plan
  variables {
    capacity_provider_strategy = "FARGATE_SPOT"
  }
  assert {
    condition     = aws_ecs_service.ecs_service.force_new_deployment == null || aws_ecs_service.ecs_service.force_new_deployment == false
    error_message = "force_new_deployment should stay off by default."
  }
}
