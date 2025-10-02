terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "aws_region" {
  type        = string
  description = "AWS region to set in provider"
  default     = "us-east-1"
}

# Validation-friendly provider config (no creds needed)
provider "aws" {
  region                      = var.aws_region
}

# Minimal resource just for syntax/schema validation
resource "aws_s3_bucket" "demo" {
  bucket = "tf-demo-bucket-example-123456" # must be globally unique if you ever apply
  tags = {
    Purpose = "validate-only"
  }
}

