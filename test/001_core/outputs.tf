output "test_fqdn" {
  description = "The FQDN we're testing against"
  value       = "basictest.${data.aws_route53_zone.test.name}"
}
