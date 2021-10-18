data "aws_route53_zone" "test" {
  zone_id = var.route53_zone_id
}

resource "aws_route53_record" "test" {
  zone_id = var.route53_zone_id
  name    = "basictest.${data.aws_route53_zone.test.name}"
  type    = "A"

  alias {
    name                   = aws_lb.test.dns_name
    zone_id                = aws_lb.test.zone_id
    evaluate_target_health = false
  }
}
