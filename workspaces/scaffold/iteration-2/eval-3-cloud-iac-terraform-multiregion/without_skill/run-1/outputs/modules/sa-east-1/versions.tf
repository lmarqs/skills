terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }

  # Configure remote state per environment. Fill in your backend and run:
  #   scripts/tf.sh sa-east-1 init -backend-config=...
  # backend "s3" {
  #   bucket = "my-terraform-state"
  #   key    = "sa-east-1/terraform.tfstate"
  #   region = "sa-east-1"
  # }
}
