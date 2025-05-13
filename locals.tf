
locals {
  existing_priorities_string = var.application_load_balancer != {} && var.application_load_balancer.listener_arn != "" ? try(data.external.listener_rules[0].result.priorities, "") : ""
  existing_priorities        = local.existing_priorities_string != "" ? split(",", local.existing_priorities_string) : []

  max_priority  = length(local.existing_priorities) > 0 ? max(local.existing_priorities...) : 0
  next_priority = local.max_priority + 1


  scale_in_queue_name = (
    var.sqs_auto_scaling.queue_name != "" ?
    var.sqs_auto_scaling.queue_name :
    var.sqs_auto_scaling.scale_in_queue_name
  )

  scale_out_queue_name = (
    var.sqs_auto_scaling.queue_name != "" ?
    var.sqs_auto_scaling.queue_name :
    var.sqs_auto_scaling.scale_out_queue_name
  )  


}
