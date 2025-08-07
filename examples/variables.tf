variable "cluster_name" {
  description = "ECS cluster name"
  type        = string
  default     = "production"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string

}
variable "subnet_ids" {
  description = "List of subnet IDs"
  type        = list(string)

}
variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)

}
variable "listener_arn" {
  description = "ARN of the ALB listener"
  type        = string
  default     = ""

}

variable "route_53_zone_id" {
  description = "Route 53 hosted zone ID for DNS record creation"
  type        = string
  default     = ""
}
