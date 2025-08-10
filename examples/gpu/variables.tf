variable "cluster_name" {
  description = "ECS cluster name"
  type        = string
  default     = "demo-cluster"
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