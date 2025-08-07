# Create IAM role for ECS task
resource "aws_iam_role" "ecs_task_role" {
  name = "alb-example-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# Attach basic ECS task execution policy
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Add any additional policies if needed
resource "aws_iam_role_policy" "additional_permissions" {
  name = "additional-permissions"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

module "single_alb_ecs_service" {
  source             = "../"
  ecs_cluster_name   = var.cluster_name
  ecs_service_name   = "role"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids
  initial_role       = aws_iam_role.ecs_task_role.name
  enable_execute_command = true

  application_load_balancer = {
    enabled                = true
    container_port         = 80
    listener_arn           = var.listener_arn
    host                   = "demo.internal.delivops.com"
    path                   = "/*"
    health_check_path      = "/health"
    route_53_host_zone_id  = var.route_53_zone_id
  }
}

//if not put the listener_arn, the plan will failed.check "" {
//create 5 resources
// expected: 1 port mapping in the task definition
