# Inline service role example.
#
# The module creates a dedicated IAM role for the service (assumable only by
# ECS tasks) and wires it into both the task role and the execution role.
# No initial_role is passed — the created role's ARN is used automatically.

module "inline_role_ecs_service" {
  source             = "../"
  ecs_cluster_name   = var.cluster_name
  ecs_service_name   = "inline-role"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  role = {
    create = true

    # Attach the AWS-managed execution policy so the role can pull images
    # and ship logs when used as the execution role.
    attach_execution_policy = true

    # Inline permissions specific to this service.
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

    # Additional managed policies attached by ARN.
    attach_policies = [
      "arn:aws:iam::aws:policy/AmazonSQSReadOnlyAccess",
    ]
  }
}
