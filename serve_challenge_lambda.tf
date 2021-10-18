resource "aws_lambda_function" "serve_challenge" {
  filename         = "${path.module}/lambdas/lacme.zip"
  source_code_hash = filebase64sha256("${path.module}/lambdas/lacme.zip")

  function_name = "lacme-${var.name}-serve_challenge"
  handler       = "lacme.serve_challenge"

  runtime = "ruby2.7"
  role    = aws_iam_role.serve_challenge.arn

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = "lacme-${var.name}"
    }
  }

  tracing_config {
    mode = "Active"
  }

  depends_on = [
    aws_iam_role_policy_attachment.serve_challenge,
    aws_cloudwatch_log_group.serve_challenge,
  ]
}

resource "aws_cloudwatch_log_group" "serve_challenge" {
  name              = "/aws/lambda/lacme-${var.name}-serve_challenge"
  retention_in_days = 120
  kms_key_id        = var.cloudwatch_kms_key_id
}

resource "aws_lb_target_group" "serve_challenge" {
  name        = "${var.name}-serve-challenge"
  target_type = "lambda"
}

resource "aws_lambda_permission" "with_lb" {
  statement_id  = "AllowExecutionFromlb"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.serve_challenge.arn
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.serve_challenge.arn
}

resource "aws_lb_target_group_attachment" "serve_challenge" {
  target_group_arn = aws_lb_target_group.serve_challenge.arn
  target_id        = aws_lambda_function.serve_challenge.arn
  depends_on       = [aws_lambda_permission.with_lb]
}

resource "aws_lb_listener_rule" "serve_challenge" {
  listener_arn = var.challenge_lb_listener_arn
  priority     = var.challenge_listener_rule_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.serve_challenge.arn
  }

  condition {
    path_pattern {
      values = ["/.well-known/acme-challenge/*"]
    }
  }
}

data "aws_iam_policy_document" "serve_challenge_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "serve_challenge" {
  name = "${var.name}-serve_challenge"

  assume_role_policy = data.aws_iam_policy_document.serve_challenge_assume_role.json
}

data "aws_iam_policy_document" "serve_challenge" {
  statement {
    actions = ["dynamodb:GetItem"]

    resources = ["arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/lacme-${var.name}"]
  }
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:aws/lambda/lacme-${var.name}-serve_challenge"]
  }
}

resource "aws_iam_policy" "serve_challenge" {
  name = "lacme-${var.name}-serve_challenge"

  policy = data.aws_iam_policy_document.serve_challenge.json
}

resource "aws_iam_role_policy_attachment" "serve_challenge" {
  role       = aws_iam_role.serve_challenge.name
  policy_arn = aws_iam_policy.serve_challenge.arn
}
