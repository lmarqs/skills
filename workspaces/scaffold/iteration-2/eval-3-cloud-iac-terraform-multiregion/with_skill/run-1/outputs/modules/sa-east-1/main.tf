terraform {
  required_version = ">= 1.13"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Resources for the sa-east-1 (São Paulo) region.
provider "aws" {
  region = "sa-east-1"
}
