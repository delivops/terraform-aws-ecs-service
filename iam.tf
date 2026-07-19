########################
# Service IAM Role (optional)
#########################
# When var.role.create = true, this module provisions a dedicated IAM role for
# the service, assumable only by the ECS tasks service. The role's ARN becomes
# the default for both task_role_arn and execution_role_arn (see
# local.service_role_arn in locals.tf), so initial_role need not be set.

resource "aws_iam_role" "this" {
  count = var.role.create ? 1 : 0

  name = var.role.name != "" ? var.role.name : "${data.aws_ecs_cluster.ecs_cluster.cluster_name}_${var.ecs_service_name}"

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

  tags = local.common_tags
}

# Inline permissions policy (optional)
resource "aws_iam_role_policy" "inline" {
  count = var.role.create && var.role.inline_policy != "" ? 1 : 0

  name   = "${aws_iam_role.this[0].name}-inline"
  role   = aws_iam_role.this[0].id
  policy = var.role.inline_policy
}

# Additional managed policies attached by ARN (optional)
resource "aws_iam_role_policy_attachment" "attached" {
  for_each = var.role.create ? toset(var.role.attach_policies) : toset([])

  role       = aws_iam_role.this[0].name
  policy_arn = each.value
}

# AmazonECSTaskExecutionRolePolicy (opt-in) so the role works as an execution role
resource "aws_iam_role_policy_attachment" "execution" {
  count = var.role.create && var.role.attach_execution_policy ? 1 : 0

  role       = aws_iam_role.this[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
