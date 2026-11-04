# Global resources for the AWS account.
#
# This module holds resources that are not tied to a single region — IAM,
# Route 53 hosted zones, CloudFront, account-wide settings, etc.
#
# Add your resources below.

data "aws_caller_identity" "current" {}
