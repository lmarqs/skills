terraform {
  required_version = ">= 1.13"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Global (account-wide / non-regional) resources go here, e.g. IAM, Route53, CloudFront.
provider "aws" {
  region = "us-east-1" # global services are managed via us-east-1
}
