# Separate task and execution roles, both created by the module.
#
# The task role starts empty and carries only what this service needs. The
# execution role gets AmazonECSTaskExecutionRolePolicy automatically, which is
# all most services need to pull images and ship logs.

module "inline_role_ecs_service" {
  source             = "../"
  ecs_cluster_name   = var.cluster_name
  ecs_service_name   = "inline-role"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  task_role = {
    create = true

    # Permissions specific to this service.
    inline_policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
          Resource = "*"
        }
      ]
    })

    attach_policies = [
      "arn:aws:iam::aws:policy/AmazonSQSReadOnlyAccess",
    ]
  }

  execution_role = {
    create = true
    # attach_execution_policy defaults to true, so nothing further is needed
    # unless the task definition references secrets.
  }
}

# Alternatively, point every service at one shared execution role and let the
# module create only the task role:
#
#   task_role      = { create = true, inline_policy = ... }
#   execution_role = { arn = aws_iam_role.shared_execution.arn }
