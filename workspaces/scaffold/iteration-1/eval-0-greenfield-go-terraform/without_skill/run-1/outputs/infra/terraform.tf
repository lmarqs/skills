terraform {
  required_version = "~> 1.14"

  backend "s3" {
    bucket = "REPLACE_ME-terraform-state"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.96"
    }
  }
}

provider "aws" {
  region = var.region
}
