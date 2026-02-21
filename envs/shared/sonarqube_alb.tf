locals {
  sonarqube_domain_name       = "sonarqube.tamacoach.net"
  sonarqube_instance_id       = "i-0cc1f06fb1d948125"
  sonarqube_security_group_id = "sg-035205f329fd1819c"
  gitlab_security_group_id    = "sg-035205f329fd1819c"
  sonarqube_alb_name          = "${local.name_prefix}-sonarqube-alb"
  sonarqube_target_group_name = "${local.name_prefix}-sonarqube-tg"
  sonarqube_certificate_domains = [
    "tamacoach.net",
    "*.tamacoach.net",
  ]
}

resource "aws_security_group" "sonarqube_alb" {
  name        = local.sonarqube_alb_name
  description = "Public ALB security group for SonarQube"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = local.sonarqube_alb_name
  })
}

resource "aws_vpc_security_group_ingress_rule" "sonarqube_alb_http_from_internet" {
  security_group_id = aws_security_group.sonarqube_alb.id
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow HTTP from internet"
}

resource "aws_vpc_security_group_ingress_rule" "sonarqube_alb_https_from_internet" {
  security_group_id = aws_security_group.sonarqube_alb.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow HTTPS from internet"
}

resource "aws_vpc_security_group_egress_rule" "sonarqube_alb_egress_all" {
  security_group_id = aws_security_group.sonarqube_alb.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow all egress"
}

resource "aws_vpc_security_group_ingress_rule" "sonarqube_from_alb_80" {
  security_group_id            = local.sonarqube_security_group_id
  referenced_security_group_id = aws_security_group.sonarqube_alb.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  description                  = "Allow SonarQube HTTP from ALB SG"
}

resource "aws_vpc_security_group_ingress_rule" "sonarqube_from_gitlab_80" {
  security_group_id            = local.sonarqube_security_group_id
  referenced_security_group_id = local.gitlab_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  description                  = "Allow SonarQube HTTP from GitLab SG"
}

resource "aws_acm_certificate" "sonarqube_wildcard" {
  domain_name               = local.sonarqube_certificate_domains[0]
  subject_alternative_names = [local.sonarqube_certificate_domains[1]]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-sonarqube-wildcard-cert"
  })
}

resource "aws_route53_record" "sonarqube_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.sonarqube_wildcard.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id         = data.aws_route53_zone.tamacoach_net_backend.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "sonarqube_wildcard" {
  certificate_arn         = aws_acm_certificate.sonarqube_wildcard.arn
  validation_record_fqdns = [for record in aws_route53_record.sonarqube_cert_validation : record.fqdn]
}

resource "aws_lb" "sonarqube_public" {
  name               = local.sonarqube_alb_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sonarqube_alb.id]
  subnets            = var.public_subnet_ids

  tags = merge(local.common_tags, {
    Name = local.sonarqube_alb_name
  })
}

resource "aws_lb_target_group" "sonarqube_http" {
  name        = local.sonarqube_target_group_name
  vpc_id      = var.vpc_id
  protocol    = "HTTP"
  port        = 80
  target_type = "instance"

  health_check {
    enabled             = true
    protocol            = "HTTP"
    path                = "/"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }

  tags = merge(local.common_tags, {
    Name = local.sonarqube_target_group_name
  })
}

resource "aws_lb_target_group_attachment" "sonarqube_instance" {
  target_group_arn = aws_lb_target_group.sonarqube_http.arn
  target_id        = local.sonarqube_instance_id
  port             = 80
}

resource "aws_lb_listener" "sonarqube_https" {
  load_balancer_arn = aws_lb.sonarqube_public.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.sonarqube_wildcard.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sonarqube_http.arn
  }
}

resource "aws_lb_listener" "sonarqube_http_redirect" {
  load_balancer_arn = aws_lb.sonarqube_public.arn
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

resource "aws_route53_record" "sonarqube_alias_a" {
  zone_id = data.aws_route53_zone.tamacoach_net_backend.zone_id
  name    = local.sonarqube_domain_name
  type    = "A"

  alias {
    name                   = aws_lb.sonarqube_public.dns_name
    zone_id                = aws_lb.sonarqube_public.zone_id
    evaluate_target_health = false
  }
}
