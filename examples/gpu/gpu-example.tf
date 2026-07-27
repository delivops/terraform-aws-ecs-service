locals {
  ec2_instance_type = "g4dn.xlarge"
  name              = "gpu"
  cluster_name      = "production"
  key_name          = "otel"
}

data "aws_ssm_parameter" "ecs_gpu_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/gpu/recommended/image_id"
}
resource "aws_iam_role" "ecs_instance_role" {
  name = "${local.name}-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_instance_attach" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}
resource "aws_iam_role_policy_attachment" "ecs_instance_role_ec2" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role_ecs" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonECS_FullAccess"
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role_ssm" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "${local.name}-instance-profile"
  role = aws_iam_role.ecs_instance_role.name
}
resource "aws_launch_template" "ecs_ec2_launch_template" {

  name_prefix   = "${local.name}-launch-template"
  instance_type = local.ec2_instance_type
  key_name      = local.key_name
  image_id      = data.aws_ssm_parameter.ecs_gpu_ami.value
  # Configure user data for GPU support
  user_data = base64encode(<<-EOF
    #!/bin/bash
    # Configure docker to use NVIDIA runtime
    sudo rm -f /etc/sysconfig/docker
    echo "DAEMON_MAXFILES=1048576" | sudo tee -a /etc/sysconfig/docker
    echo "OPTIONS=\"--default-ulimit nofile=32768:65536 --default-runtime nvidia\"" | sudo tee -a /etc/sysconfig/docker
    echo "DAEMON_PIDFILE_TIMEOUT=10" | sudo tee -a /etc/sysconfig/docker
    sudo systemctl restart docker

    # Register the instance with ECS cluster
    echo "ECS_CLUSTER=${local.cluster_name}" | sudo tee -a /etc/ecs/ecs.config
    echo ECS_ENABLE_GPU_SUPPORT=true >> /etc/ecs/ecs.config

  EOF
  )

  vpc_security_group_ids = var.security_group_ids

  # IAM instance profile
  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance_profile.name
  }

  # Block device mappings
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 30
      volume_type = "gp3"
      encrypted   = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "aws-autoscaling-group" {
  name                  = "${local.cluster_name}-asg"
  vpc_zone_identifier   = tolist(var.subnet_ids)
  desired_capacity      = 1
  max_size              = 6
  min_size              = 1
  health_check_type     = "EC2"
  protect_from_scale_in = true

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupPendingInstances",
    "GroupStandbyInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances"
  ]

  launch_template {
    id      = aws_launch_template.ecs_ec2_launch_template.id
    version = aws_launch_template.ecs_ec2_launch_template.latest_version
  }

  instance_refresh {
    strategy = "Rolling"
  }
  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }
}

resource "aws_ecs_capacity_provider" "ecs_capacity_provider" {
  name = "capacity_provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.aws-autoscaling-group.arn
    managed_termination_protection = "ENABLED"

    managed_scaling {
      maximum_scaling_step_size = 5
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 100
    }
  }
}

###################################################
# Create an ECS Cluster capacity Provider
###################################################
resource "aws_ecs_cluster_capacity_providers" "ecs_cluster_capacity_provider" {
  cluster_name       = local.cluster_name
  capacity_providers = [aws_ecs_capacity_provider.ecs_capacity_provider.name]
}


module "gpu_ecs_service" {
  source = "../../"

  ecs_cluster_name           = var.cluster_name
  ecs_service_name           = "gpu"
  vpc_id                     = var.vpc_id
  subnet_ids                 = var.subnet_ids
  security_group_ids         = var.security_group_ids
  ecs_launch_type            = "EC2"
  gpu_count                  = 1
  capacity_provider_strategy = aws_ecs_capacity_provider.ecs_capacity_provider.name
}

