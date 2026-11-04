output "account_id" {
  description = "The AWS account ID this module is operating in."
  value       = data.aws_caller_identity.current.account_id
}
