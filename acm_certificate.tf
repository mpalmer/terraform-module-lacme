resource "tls_private_key" "temp" {
  algorithm = "RSA"
}

resource "tls_self_signed_cert" "temp" {
  key_algorithm   = "RSA"
  private_key_pem = tls_private_key.temp.private_key_pem

  subject {
    common_name = "${var.name}.lacme.example"
  }

  validity_period_hours = 1000

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
  ]
}

resource "aws_acm_certificate" "lacme" {
  private_key      = tls_private_key.temp.private_key_pem
  certificate_body = tls_self_signed_cert.temp.cert_pem

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      private_key,
      certificate_body,
    ]
  }
}
