resource "aws_kms_key" "lacme" {
  description             = "Test key for L'ACME"
  deletion_window_in_days = 7

  policy = data.aws_iam_policy_document.kms.json
}

data "aws_iam_policy_document" "kms" {
  statement {
    sid = "Full admins"
    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
        data.aws_caller_identity.current.arn
      ]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }
  statement {
    sid = "Let Lambda encrypt with the key"
    principals {
      type = "AWS"
      identifiers = [
        module.lacme.lambda_role_arn
      ]
    }
    actions = [
      "kms:DescribeKey",
      "kms:Encrypt"
    ]
    resources = ["*"]
  }
}
