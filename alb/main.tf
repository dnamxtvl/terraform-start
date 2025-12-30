resource "aws_lb" "application_load_balancer" {
  name               = "quiz-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = [for subnet in var.vpc.public_subnets : subnet.id]
  security_groups    = [var.sg.lb]

  count = 0

  tags = {
    Name = "quiz-alb"
  }
}

resource "aws_lb_target_group" "target_group" {
  name        = "quiz-tg"
  port        = var.container_nginx_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc.vpc_id

  health_check {
    path                = "/healthcheck"
    protocol            = "HTTP"
    matcher             = "200"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 10
    interval            = 30
  }

  tags = {
    Name = "quiz-tg"
  }
}

data "aws_route53_zone" "selected_zone" {
  name         = var.domain_name
  private_zone = false
}


# HTTP listener - redirect to HTTPS
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.application_load_balancer.arn
  port              = "80"
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

# HTTPS listener - forward to target group
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.application_load_balancer.arn
  port              = "443"
  protocol          = "HTTPS"

  certificate_arn = var.lb_acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }
}

resource "aws_route53_record" "route53_A_record" {
  zone_id = data.aws_route53_zone.selected_zone.zone_id
  name    = "api.${var.domain_name}"
  type    = "A"
  alias {
    name                   = aws_lb.application_load_balancer.dns_name
    zone_id                = aws_lb.application_load_balancer.zone_id
    evaluate_target_health = true
  }
}
