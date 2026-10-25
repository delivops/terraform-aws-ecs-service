# Sign-in at the ALB (Cognito), the rule priority, and the paths that skip the sign-in. Mocked AWS.
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

run "no_auth_is_unchanged" {
  command = plan
  variables {
    application_load_balancer = {
      enabled      = true
      listener_arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/main/1/2"
      host         = "api.example.com"
    }
  }
  assert {
    condition     = length(aws_lb_listener_rule.rule[0].action) == 1 && aws_lb_listener_rule.rule[0].action[0].type == "forward"
    error_message = "Without authenticate_cognito the rule only forwards."
  }
  assert {
    condition     = length(aws_lb_listener_rule.rule_unauthenticated) == 0
    error_message = "No unauthenticated rule without unauthenticated_paths."
  }
}

run "cognito_then_forward_with_open_paths_first" {
  command = plan
  variables {
    application_load_balancer = {
      enabled                = true
      listener_arn           = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/main/1/2"
      host                   = "api.example.com"
      listener_rule_priority = 10
      authenticate_cognito = {
        user_pool_arn       = "arn:aws:cognito-idp:us-east-1:123456789012:userpool/us-east-1_abc"
        user_pool_client_id = "client"
        user_pool_domain    = "example-auth"
      }
      unauthenticated_paths = ["/hooks/*", "/health"]
    }
  }
  assert {
    condition     = [for a in aws_lb_listener_rule.rule[0].action : a.type] == ["authenticate-cognito", "forward"]
    error_message = "The main rule signs in, then forwards."
  }
  assert {
    condition     = aws_lb_listener_rule.rule[0].priority == 11 && aws_lb_listener_rule.rule_unauthenticated[0].priority == 10
    error_message = "The unauthenticated rule takes the priority; the signed-in rule the next one."
  }
  assert {
    condition     = aws_lb_listener_rule.rule_unauthenticated[0].action[0].type == "forward"
    error_message = "The unauthenticated paths forward without a sign-in."
  }
}

run "open_paths_need_auth_and_priority" {
  command = plan
  variables {
    application_load_balancer = {
      enabled               = true
      listener_arn          = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/main/1/2"
      host                  = "api.example.com"
      unauthenticated_paths = ["/health"]
    }
  }
  expect_failures = [var.application_load_balancer]
}

run "at_most_four_paths_with_a_host" {
  command = plan
  variables {
    application_load_balancer = {
      enabled                = true
      listener_arn           = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/main/1/2"
      host                   = "api.example.com"
      listener_rule_priority = 10
      authenticate_cognito = {
        user_pool_arn       = "arn:aws:cognito-idp:us-east-1:123456789012:userpool/us-east-1_abc"
        user_pool_client_id = "client"
        user_pool_domain    = "example-auth"
      }
      unauthenticated_paths = ["/a", "/b", "/c", "/d", "/e"]
    }
  }
  expect_failures = [var.application_load_balancer]
}
