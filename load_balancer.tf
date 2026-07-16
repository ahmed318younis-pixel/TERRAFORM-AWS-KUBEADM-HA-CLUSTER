resource "aws_lb" "application" {
  name                       = local.alb_name
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = [for subnet in aws_subnet.public : subnet.id]
  enable_deletion_protection = var.enable_alb_deletion_protection
  drop_invalid_header_fields = true
  enable_http2               = true
  idle_timeout               = 60

  depends_on = [aws_internet_gateway.main]

  tags = {
    Name = local.alb_name
  }
}

resource "aws_lb_target_group" "workers" {
  name        = local.tg_name
  port        = var.alb_node_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  deregistration_delay = 30

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
    timeout             = 5
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = "200-399"
  }

  tags = {
    Name = local.tg_name
  }
}

resource "aws_lb_target_group_attachment" "workers" {
  for_each = aws_instance.worker

  target_group_arn = aws_lb_target_group.workers.arn
  target_id        = each.value.id
  port             = var.alb_node_port
}

resource "aws_lb_listener" "http_forward" {
  count = var.acm_certificate_arn == null ? 1 : 0

  load_balancer_arn = aws_lb.application.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.workers.arn
  }
}

resource "aws_lb_listener" "http_redirect" {
  count = var.acm_certificate_arn == null ? 0 : 1

  load_balancer_arn = aws_lb.application.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  count = var.acm_certificate_arn == null ? 0 : 1

  load_balancer_arn = aws_lb.application.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.workers.arn
  }
}
