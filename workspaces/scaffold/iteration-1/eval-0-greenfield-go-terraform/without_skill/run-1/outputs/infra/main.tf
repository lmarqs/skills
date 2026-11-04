locals {
  name = var.service_name
}

# ---------------------------------------------------------------------------
# S3 bucket
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "this" {
  bucket_prefix = "${local.name}-"
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

# ---------------------------------------------------------------------------
# Lambda
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${local.name}-lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "this" {
  function_name = local.name
  role          = aws_iam_role.lambda.arn

  filename         = var.lambda_package
  source_code_hash = filebase64sha256(var.lambda_package)

  runtime       = "provided.al2023"
  handler       = "bootstrap"
  architectures = ["arm64"]

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.this.bucket
    }
  }
}
