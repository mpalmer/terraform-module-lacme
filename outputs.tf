output "acm_certificate_arn" {
  description = "The ARN of the ACM certificate managed by L'ACME, for use in HTTPS LB listeners and for related purposes"
  value       = aws_acm_certificate.lacme.arn
}

output "lambda_role_arn" {
  description = "The ARN of the IAM role which the issue_cert Lambda assumes"
  value       = aws_iam_role.issue_cert.arn
}

output "dynamodb_table_arn" {
  description = "The ARN of the DynamoDB table name that stores the L'ACME certificate/key/chain"
  value       = aws_dynamodb_table.lacme.arn
}
