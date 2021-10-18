resource "aws_security_group" "test_lb" {
  name        = "lacme-test-basic-lb"
  description = "LACME 001_basic load balancer testing security group"
  vpc_id      = aws_vpc.test.id
}

resource "aws_security_group_rule" "http_to_test_lb_from_internet" {
  security_group_id = aws_security_group.test_lb.id
  description       = "Let the Internet make requests to the load balancer"

  type        = "ingress"
  from_port   = 80
  to_port     = 80
  protocol    = "TCP"
  cidr_blocks = ["0.0.0.0/0"] # tfsec:ignore:AWS006
}

resource "aws_lb" "test" {
  name            = "basic-test-lb"
  internal        = false # tfsec:ignore:AWS005
  security_groups = [aws_security_group.test_lb.id]
  subnets         = [aws_subnet.test-a.id, aws_subnet.test-b.id]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.test.arn

  port     = 80
  protocol = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = 404
    }
  }
}
