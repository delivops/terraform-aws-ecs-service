###############################################################################
# Example 1: Minimal, opinionated defaults
###############################################################################
module "sqs_ecs_service_minimal" {
  source = "../"

  ecs_cluster_name   = var.cluster_name
  ecs_service_name   = "screenshot-maker"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  sqs_autoscaling = {
    enabled               = true
    queue_name            = "screenshot-maker-production-queue"
    min_replicas          = 0
    max_replicas          = 500
    scale_out_age_seconds = 120
    scale_in_age_seconds  = 20
  }
}

###############################################################################
# Example 2: Customized ladder & timings
###############################################################################
module "sqs_ecs_service_custom" {
  source = "../"

  ecs_cluster_name   = var.cluster_name
  ecs_service_name   = "image-processor"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  sqs_autoscaling = {
    enabled               = true
    scale_out_queue_name  = "images-out"
    scale_in_queue_name   = "images-out"
    min_replicas          = 2
    max_replicas          = 300
    scale_out_age_seconds = 90
    scale_in_age_seconds  = 15

    # Custom cooldowns
    scale_out_cooldown = 90
    scale_in_cooldown  = 900

    # Custom step ladder for proportional scale-out
    scale_out_steps = [
      { lower = 0, upper = 60, change = 2 },
      { lower = 60, upper = 240, change = 6 },
      { lower = 240, upper = null, change = 18 }
    ]

    # Slower scale-in (2 tasks at a time)
    scale_in_step = -2

    # Enable smoothing with 3-point SMA
    age_sma_points = 3
  }
}

###############################################################################
# Example 3: Maximum stability (wait for queue to be completely empty)
###############################################################################
module "sqs_ecs_service_stable" {
  source = "../"

  ecs_cluster_name   = var.cluster_name
  ecs_service_name   = "batch-processor"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  sqs_autoscaling = {
    enabled               = true
    queue_name            = "batch-jobs"
    min_replicas          = 1
    max_replicas          = 100
    scale_out_age_seconds = 60
    scale_in_age_seconds  = 10

    # Require queue to be completely empty before scaling in
    # Use this when you want maximum stability or have oscillation risk
    require_empty_for_scale_in = true
  }
}

// Expected resources to create per module:
//
// Default settings (require_empty_for_scale_in = false): 5 resources
// - 1x AppAutoScaling Target
// - 1x Scale-out Policy (StepScaling)
// - 1x Scale-in Policy (StepScaling)
// - 1x Age OUT alarm
// - 1x Age IN alarm (triggers scale-in directly)
//
// With stability mode (require_empty_for_scale_in = true): 8 resources
// - Same as above, plus:
// - 2x Queue empty alarms (visible + not-visible)
// - 1x Composite scale-in safety alarm
//
// When age_sma_points > 1: uses metric math alarm instead of simple alarm for OUT
