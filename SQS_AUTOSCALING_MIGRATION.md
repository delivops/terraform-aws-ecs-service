# SQS Autoscaling Migration Guide

## Breaking Change

The `sqs_auto_scaling` variable has been redesigned as `sqs_autoscaling` (no underscore between "auto" and "scaling").

This is a **breaking change** that requires updating your Terraform configuration.

## Key Differences

| Aspect | Old (`sqs_auto_scaling`) | New (`sqs_autoscaling`) |
|--------|--------------------------|-------------------------|
| Metric | `ApproximateNumberOfMessagesVisible` (backlog) | `ApproximateAgeOfOldestMessage` (latency) |
| Threshold | Message count | Message age in seconds |
| Scale-out | Fixed step size | Proportional step ladder |
| Scale-in safety | None | Optional composite alarm |

## Parameter Mapping

| Old Parameter | New Parameter | Notes |
|---------------|---------------|-------|
| `enabled` | `enabled` | No change |
| `min_replicas` | `min_replicas` | No change |
| `max_replicas` | `max_replicas` | No change |
| `queue_name` | `queue_name` | No change |
| `scale_in_queue_name` | `scale_in_queue_name` | No change |
| `scale_out_queue_name` | `scale_out_queue_name` | No change |
| `scale_in_cooldown` | `scale_in_cooldown` | No change |
| `scale_out_cooldown` | `scale_out_cooldown` | No change |
| `scale_in_step` | `scale_in_step` | Now expects negative value (e.g., `-1`) |
| `scale_out_step` | `scale_out_steps` | Now a list of step objects |
| `scale_out_threshold` | `scale_out_age_seconds` | Now in seconds (age-based) |
| `scale_in_threshold` | `scale_in_age_seconds` | Now in seconds (age-based) |
| `scale_out_interval` | - | Removed (fixed at 60s) |
| `scale_in_interval` | - | Removed (fixed at 300s) |
| `scale_in_datapoints_to_alarm` | - | Removed (fixed at 3) |
| `scale_out_datapoints_to_alarm` | - | Removed (fixed at 3) |
| `scale_in_metric_name` | - | Removed (always uses Age) |
| `scale_out_metric_name` | - | Removed (always uses Age) |
| - | `require_empty_for_scale_in` | New: wait for queue empty before scale-in |
| - | `age_sma_points` | New: smoothing via Simple Moving Average |

## Migration Example

### Before (Old Schema)

```hcl
sqs_auto_scaling = {
  enabled                      = true
  min_replicas                 = 1
  max_replicas                 = 10
  queue_name                   = "my-queue"
  scale_out_threshold          = 100  # 100 messages
  scale_in_threshold           = 0    # 0 messages
  scale_out_step               = 2
  scale_in_step                = 1
  scale_in_datapoints_to_alarm = 15
}
```

### After (New Schema)

```hcl
sqs_autoscaling = {
  enabled               = true
  min_replicas          = 1
  max_replicas          = 10
  queue_name            = "my-queue"
  scale_out_age_seconds = 120  # Scale out when messages wait 2+ minutes
  scale_in_age_seconds  = 20   # Scale in when messages wait < 20 seconds

  # For behavior similar to old "wait for empty queue":
  require_empty_for_scale_in = true
}
```

## Choosing Thresholds

The new age-based thresholds are more intuitive:

- **`scale_out_age_seconds`**: "Messages should not wait longer than X seconds"
- **`scale_in_age_seconds`**: "If messages are processed within Y seconds, we have excess capacity"

**Rule of thumb**: Set `scale_out_age_seconds` to your SLA target, and `scale_in_age_seconds` to ~10-20% of that value.

## Terraform State

After updating your configuration, run:

```bash
terraform plan
```

Terraform will show resources being replaced. This is expected - the old alarms and policies will be destroyed and new ones created with the updated logic.
