resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.test.arn
  certificate_arn   = module.lacme.acm_certificate_arn

  port     = 443
  protocol = "HTTPS"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = 404
    }
  }
}

resource "aws_security_group_rule" "https_to_test_lb_from_internet" {
  security_group_id = aws_security_group.test_lb.id
  description       = "Let the Internet make HTTPS requests to the load balancer"

  type        = "ingress"
  from_port   = 443
  to_port     = 443
  protocol    = "TCP"
  cidr_blocks = ["0.0.0.0/0"] # tfsec:ignore:AWS006
}
