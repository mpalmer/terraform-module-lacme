resource "aws_lambda_function" "issue_cert" {
  filename         = "${path.module}/lambdas/lacme.zip"
  source_code_hash = filebase64sha256("${path.module}/lambdas/lacme.zip")

  function_name = "lacme-${var.name}-issue_cert"
  handler       = "lacme.issue_cert"

  runtime = "ruby2.7"
  role    = aws_iam_role.issue_cert.arn

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = "lacme-${var.name}"
      ACME_DIRECTORY_URL  = var.acme_directory_url
      CERTIFICATE_NAMES   = join(",", var.certificate_names)
      ACM_CERTIFICATE_ARN = aws_acm_certificate.lacme.arn
      KMS_KEY_ARN         = var.kms_key_arn
    }
  }

  tracing_config {
    mode = "Active"
  }

  timeout = 900

  depends_on = [
    aws_iam_role_policy_attachment.issue_cert,
    aws_cloudwatch_log_group.issue_cert,
  ]
}

resource "aws_cloudwatch_log_group" "issue_cert" {
  name              = "/aws/lambda/lacme-${var.name}-issue_cert"
  retention_in_days = 120
  kms_key_id        = var.cloudwatch_kms_key_id
}

resource "aws_cloudwatch_event_rule" "run_issue_cert" {
  name                = "lacme-${var.name}-run-issue_cert-daily"
  description         = "Run the issue_cert function once a day, to renew cert if needed"
  schedule_expression = "rate(1 day)"
}

resource "aws_cloudwatch_event_target" "issue_cert" {
  rule = aws_cloudwatch_event_rule.run_issue_cert.name
  arn  = aws_lambda_function.issue_cert.arn
}

resource "aws_lambda_permission" "issue_cert" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.issue_cert.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.run_issue_cert.arn
}

data "aws_iam_policy_document" "issue_cert_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "issue_cert" {
  name = "lacme-${var.name}-issue_cert"

  assume_role_policy = data.aws_iam_policy_document.issue_cert_assume_role.json
}

data "aws_iam_policy_document" "issue_cert" {
  statement {
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
    ]
    resources = ["arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/lacme-${var.name}"]
  }
  statement {
    actions = [
      "dynamodb:GetRecords",
      "dynamodb:GetShardIterator",
      "dynamodb:DescribeStream",
    ]
    resources = ["arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/lacme-${var.name}/stream/*"]
  }
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:ap-southeast-2:616923951253:log-group:/aws/lambda/lacme-${var.name}-issue_cert:*"]
  }
  statement {
    actions = [
      "acm:DescribeCertificate",
      "acm:ImportCertificate",
    ]
    resources = [aws_acm_certificate.lacme.arn]
  }
}

resource "aws_iam_policy" "issue_cert" {
  name = "lacme-${var.name}-issue_cert"

  policy = data.aws_iam_policy_document.issue_cert.json
}

resource "aws_iam_role_policy_attachment" "issue_cert" {
  role       = aws_iam_role.issue_cert.name
  policy_arn = aws_iam_policy.issue_cert.arn
}

resource "aws_lambda_event_source_mapping" "table_changed" {
  event_source_arn  = aws_dynamodb_table.lacme.stream_arn
  function_name     = aws_lambda_function.issue_cert.arn
  starting_position = "TRIM_HORIZON"
}

resource "aws_dynamodb_table_item" "trigger_issue_cert_run" {
  table_name = aws_dynamodb_table.lacme.name
  hash_key   = aws_dynamodb_table.lacme.hash_key

  # The combination of the table_changed event source mapping and this
  # resource, which changes every time the lambda is updated, ensures
  # that an issue_cert run is triggered as soon as there's a configuration
  # change -- for instance, if the list of names to issue the certificate
  # for needs to be modified.
  item = jsonencode({
    k = { S = "lambda_function_last_modified" },
    v = { S = aws_lambda_function.issue_cert.last_modified },
  })

  # No point triggering an issue_cert run until everything is in place
  # for that run to succeed, hence this long list of resources that need
  # to be done first.
  depends_on = [
    aws_lambda_event_source_mapping.table_changed,
    aws_lb_target_group_attachment.serve_challenge
  ]
}
