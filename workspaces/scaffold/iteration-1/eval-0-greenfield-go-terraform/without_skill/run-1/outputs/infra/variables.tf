variable "region" {
  type        = string
  description = "AWS region to deploy into"
  default     = "us-east-1"
}

variable "service_name" {
  type        = string
  description = "Logical service name, used as a prefix for resource names"
  default     = "go-api-service"
}

variable "lambda_package" {
  type        = string
  description = "Path to the built Lambda zip (produced by `mise run build:lambda`)"
  default     = "../dist/lambda.zip"
}
