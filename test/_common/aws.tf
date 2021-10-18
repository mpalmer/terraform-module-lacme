provider "aws" {
  default_tags {
    tags = {
      "LacmeTest" = "001_basic"
    }
  }
}

data "aws_caller_identity" "current" {}
