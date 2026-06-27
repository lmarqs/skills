variable "region" {
  description = "AWS region used to anchor global resources (IAM, Route 53, CloudFront)."
  type        = string
  default     = "us-east-1"
}
