########################
# Task and execution roles (optional)
#########################
# Each role is independently either created here (create = true), supplied by
# ARN (arn = "..."), or absent. Both are assumable only by the ECS tasks service.
#
# The two roles are shaped the same but default differently, because their jobs
# differ: the task role carries whatever the application needs and so starts
# empty, while the execution role's job is the same for every service and is
# covered by AmazonECSTaskExecutionRolePolicy.

########################
# Task role — what the container assumes
#########################

# The module previously created a single aws_iam_role.this used for both slots.
# It carried the caller's inline_policy, i.e. application permissions, so it
# becomes the task role rather than being destroyed and recreated.
moved {
  from = aws_iam_role.this
  to   = aws_iam_role.task
}

resource "aws_iam_role" "task" {
  count = var.task_role.create ? 1 : 0

  name = var.task_role.name != "" ? var.task_role.name : "${data.aws_ecs_cluster.ecs_cluster.cluster_name}_${var.ecs_service_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "task_inline" {
  count = var.task_role.create && var.task_role.inline_policy != "" ? 1 : 0

  name   = "${aws_iam_role.task[0].name}-inline"
  role   = aws_iam_role.task[0].id
  policy = var.task_role.inline_policy
}

resource "aws_iam_role_policy_attachment" "task_attached" {
  for_each = var.task_role.create ? toset(var.task_role.attach_policies) : toset([])

  role       = aws_iam_role.task[0].name
  policy_arn = each.value
}

########################
# Execution role — what the ECS agent assumes to start the task
#########################

resource "aws_iam_role" "execution" {
  count = var.execution_role.create ? 1 : 0

  name = var.execution_role.name != "" ? var.execution_role.name : "${data.aws_ecs_cluster.ecs_cluster.cluster_name}_${var.ecs_service_name}_execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
      }
    ]
  })

  tags = local.common_tags
}

# ECR pull and log write. Without it a created execution role cannot start a
# task, which surfaces as CannotPullContainerError rather than a permissions
# error, so it is attached by default.
resource "aws_iam_role_policy_attachment" "execution_managed" {
  count = var.execution_role.create && var.execution_role.attach_execution_policy ? 1 : 0

  role       = aws_iam_role.execution[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# AmazonECSTaskExecutionRolePolicy does not grant access to secrets. A task
# definition referencing secrets needs ssm:GetParameters or
# secretsmanager:GetSecretValue added here.
resource "aws_iam_role_policy" "execution_inline" {
  count = var.execution_role.create && var.execution_role.inline_policy != "" ? 1 : 0

  name   = "${aws_iam_role.execution[0].name}-inline"
  role   = aws_iam_role.execution[0].id
  policy = var.execution_role.inline_policy
}

resource "aws_iam_role_policy_attachment" "execution_attached" {
  for_each = var.execution_role.create ? toset(var.execution_role.attach_policies) : toset([])

  role       = aws_iam_role.execution[0].name
  policy_arn = each.value
}
