terraform {
  required_version = ">= 1.13"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Resources for the us-east-1 (N. Virginia) region.
provider "aws" {
  region = "us-east-1"
}
