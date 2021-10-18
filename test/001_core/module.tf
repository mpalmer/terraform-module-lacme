module "lacme" {
  providers = {
    aws = aws
  }

  source = "../../"

  name                      = "basic-test"
  certificate_names         = ["basictest.${data.aws_route53_zone.test.name}"]
  acme_directory_url        = "https://acme-staging-v02.api.letsencrypt.org/directory"
  challenge_lb_listener_arn = aws_lb_listener.http.arn
  kms_key_arn               = aws_kms_key.lacme.key_id

  depends_on = [
    aws_route53_record.test,
  ]
}
