provider "aws" {
  region = var.region

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Module    = "global"
    }
  }
}

# Kubernetes / Helm providers are wired to an EKS cluster when this module
# manages in-cluster resources. Point these at the relevant cluster outputs.
#
# provider "kubernetes" {
#   host                   = aws_eks_cluster.this.endpoint
#   cluster_ca_certificate = base64decode(aws_eks_cluster.this.certificate_authority[0].data)
#   exec {
#     api_version = "client.authentication.k8s.io/v1beta1"
#     command     = "aws"
#     args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.this.name]
#   }
# }
#
# provider "helm" {
#   kubernetes {
#     host                   = aws_eks_cluster.this.endpoint
#     cluster_ca_certificate = base64decode(aws_eks_cluster.this.certificate_authority[0].data)
#     exec {
#       api_version = "client.authentication.k8s.io/v1beta1"
#       command     = "aws"
#       args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.this.name]
#     }
#   }
# }
