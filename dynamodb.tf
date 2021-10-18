# PitR and table-level encryption are not necessary for this use-case
# tfsec:ignore:AWS086 tfsec:ignore:AWS092
resource "aws_dynamodb_table" "lacme" {
  name         = "lacme-${var.name}"
  billing_mode = "PAY_PER_REQUEST"

  hash_key = "k"

  attribute {
    name = "k"
    type = "S"
  }

  ttl {
    enabled        = true
    attribute_name = "ttl"
  }

  stream_enabled   = true
  stream_view_type = "NEW_IMAGE"
}
