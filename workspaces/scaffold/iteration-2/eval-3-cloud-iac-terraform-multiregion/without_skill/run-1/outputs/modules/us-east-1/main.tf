# Resources for the us-east-1 (N. Virginia) region.
#
# This is where regional infrastructure lives — VPCs, EKS clusters, RDS, and
# the Helm/Kubernetes workloads deployed onto the cluster.
#
# Add your resources below.

data "aws_caller_identity" "current" {}
