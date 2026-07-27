terraform {
  # 1.9 introduced validation rules that can reference other input variables,
  # which the network_mode validations rely on.
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}
