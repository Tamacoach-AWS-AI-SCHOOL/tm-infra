locals {
  backend_envs = {
    dev = {
      domain     = "api-stage.tamacoach.net"
      subnet_ids = ["subnet-0391770b02ef5522b", "subnet-0d4af0728250a20af"]
    }
    prod = {
      domain     = "api.tamacoach.net"
      subnet_ids = ["subnet-0ab5699d45f941b16", "subnet-0304ae6e12f57604d"]
    }
  }

  backend_apigw_certificate_arn = "arn:aws:acm:ap-northeast-2:193629269600:certificate/502e2b0d-4aaa-456d-9d4c-f2178d157e9c"

  backend_subnet_ids_resolved = {
    dev  = [for subnet in data.aws_subnet.tamacoach_backend_dev : subnet.id]
    prod = [for subnet in data.aws_subnet.tamacoach_backend_prod : subnet.id]
  }

  backend_health_lambda_name = "${local.name_prefix}-backend-health"
}

data "aws_vpc" "tamacoach_shared" {
  id = var.vpc_id
}

data "aws_route53_zone" "tamacoach_net_backend" {
  name         = "tamacoach.net"
  private_zone = false
}

data "aws_subnet" "tamacoach_backend_dev" {
  for_each = toset(local.backend_envs.dev.subnet_ids)
  id       = each.value
}

data "aws_subnet" "tamacoach_backend_prod" {
  for_each = toset(local.backend_envs.prod.subnet_ids)
  id       = each.value
}

data "aws_eks_cluster" "tamacoach_backend" {
  for_each = local.backend_envs
  name     = "eks-${each.key}"
}

resource "aws_ecr_repository" "tamacoach_shared_backend" {
  name                 = "${local.name_prefix}-backend"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-backend"
    Environment = local.env
  })
}

resource "aws_security_group" "tamacoach_shared_backend_nlb" {
  for_each = local.backend_envs

  name        = "${local.name_prefix}-backend-${each.key}-nlb-sg"
  description = "Internal NLB security group for ${each.key} backend traffic"
  vpc_id      = data.aws_vpc.tamacoach_shared.id

  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-backend-${each.key}-nlb-sg"
    Environment = each.key
  })
}

resource "aws_security_group" "tamacoach_shared_backend_vpclink" {
  for_each = local.backend_envs

  name        = "${local.name_prefix}-backend-${each.key}-vpclink-sg"
  description = "API Gateway VPC Link security group for ${each.key}"
  vpc_id      = data.aws_vpc.tamacoach_shared.id

  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-backend-${each.key}-vpclink-sg"
    Environment = each.key
  })
}

resource "aws_vpc_security_group_egress_rule" "tamacoach_shared_backend_vpclink_to_nlb_8000" {
  for_each = local.backend_envs

  security_group_id            = aws_security_group.tamacoach_shared_backend_vpclink[each.key].id
  ip_protocol                  = "tcp"
  from_port                    = 8000
  to_port                      = 8000
  referenced_security_group_id = aws_security_group.tamacoach_shared_backend_nlb[each.key].id
  description                  = "Allow VPC Link ${each.key} to internal NLB on 8000/TCP"
}

resource "aws_vpc_security_group_ingress_rule" "tamacoach_shared_backend_nlb_from_vpclink_8000" {
  for_each = local.backend_envs

  security_group_id            = aws_security_group.tamacoach_shared_backend_nlb[each.key].id
  ip_protocol                  = "tcp"
  from_port                    = 8000
  to_port                      = 8000
  referenced_security_group_id = aws_security_group.tamacoach_shared_backend_vpclink[each.key].id
  description                  = "Allow API Gateway VPC Link ${each.key} to NLB on 8000/TCP"
}

resource "aws_lb" "tamacoach_shared_backend_internal" {
  for_each = local.backend_envs

  name               = "${local.name_prefix}-be-${each.key}-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = local.backend_subnet_ids_resolved[each.key]
  security_groups    = [aws_security_group.tamacoach_shared_backend_nlb[each.key].id]

  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-backend-${each.key}-nlb"
    Environment = each.key
  })
}

resource "aws_lb_target_group" "tamacoach_shared_backend" {
  for_each = local.backend_envs

  name        = "${local.name_prefix}-backend-${each.key}-tg"
  port        = 8000
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = data.aws_vpc.tamacoach_shared.id

  health_check {
    enabled             = true
    protocol            = "HTTP"
    path                = "/health"
    port                = "8000"
    matcher             = "200-399"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
  }

  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-backend-${each.key}-tg"
    Environment = each.key
  })
}

resource "aws_lb_listener" "tamacoach_shared_backend_tcp_8000" {
  for_each = local.backend_envs

  load_balancer_arn = aws_lb.tamacoach_shared_backend_internal[each.key].arn
  port              = 8000
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tamacoach_shared_backend[each.key].arn
  }
}

resource "aws_apigatewayv2_vpc_link" "tamacoach_shared_backend" {
  for_each = local.backend_envs

  name               = "${local.name_prefix}-backend-${each.key}-vpclink"
  subnet_ids         = local.backend_subnet_ids_resolved[each.key]
  security_group_ids = [aws_security_group.tamacoach_shared_backend_vpclink[each.key].id]

  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-backend-${each.key}-vpclink"
    Environment = each.key
  })
}

resource "aws_cloudwatch_log_group" "tamacoach_shared_backend_apigw_access" {
  for_each = local.backend_envs

  name              = "/aws/apigateway/${local.name_prefix}-backend-${each.key}"
  retention_in_days = 7
  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-backend-${each.key}-access-log"
    Environment = each.key
  })
}

resource "aws_apigatewayv2_api" "tamacoach_shared_backend" {
  for_each = local.backend_envs

  name          = "${local.name_prefix}-backend-${each.key}-http-api"
  protocol_type = "HTTP"
  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-backend-${each.key}-http-api"
    Environment = each.key
  })
}

data "archive_file" "tamacoach_shared_backend_health_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/health/index.py"
  output_path = "${path.module}/lambda/health/index.zip"
}

resource "aws_iam_role" "tamacoach_shared_backend_health_lambda" {
  name = "${local.name_prefix}-backend-health-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-backend-health-lambda-role"
    Environment = local.env
  })
}

resource "aws_iam_role_policy_attachment" "tamacoach_shared_backend_health_lambda_basic" {
  role       = aws_iam_role.tamacoach_shared_backend_health_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "tamacoach_shared_backend_health" {
  function_name    = local.backend_health_lambda_name
  role             = aws_iam_role.tamacoach_shared_backend_health_lambda.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  filename         = data.archive_file.tamacoach_shared_backend_health_lambda.output_path
  source_code_hash = data.archive_file.tamacoach_shared_backend_health_lambda.output_base64sha256
  timeout          = 3

  tags = merge(local.common_tags, {
    Name        = local.backend_health_lambda_name
    Environment = local.env
  })

  depends_on = [aws_iam_role_policy_attachment.tamacoach_shared_backend_health_lambda_basic]
}

resource "aws_apigatewayv2_integration" "tamacoach_shared_backend_private" {
  for_each = local.backend_envs

  api_id                 = aws_apigatewayv2_api.tamacoach_shared_backend[each.key].id
  integration_type       = "HTTP_PROXY"
  integration_method     = "ANY"
  integration_uri        = aws_lb_listener.tamacoach_shared_backend_tcp_8000[each.key].arn
  payload_format_version = "1.0"
  connection_type        = "VPC_LINK"
  connection_id          = aws_apigatewayv2_vpc_link.tamacoach_shared_backend[each.key].id
}

resource "aws_apigatewayv2_integration" "tamacoach_shared_backend_health_lambda" {
  for_each = local.backend_envs

  api_id                 = aws_apigatewayv2_api.tamacoach_shared_backend[each.key].id
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  integration_uri        = aws_lambda_function.tamacoach_shared_backend_health.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "tamacoach_shared_backend_health" {
  for_each = local.backend_envs

  api_id    = aws_apigatewayv2_api.tamacoach_shared_backend[each.key].id
  route_key = "GET /health"
  target    = "integrations/${aws_apigatewayv2_integration.tamacoach_shared_backend_health_lambda[each.key].id}"
}

resource "aws_apigatewayv2_route" "tamacoach_shared_backend_proxy" {
  for_each = local.backend_envs

  api_id    = aws_apigatewayv2_api.tamacoach_shared_backend[each.key].id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.tamacoach_shared_backend_private[each.key].id}"
}

resource "aws_lambda_permission" "tamacoach_shared_backend_health_from_apigw" {
  for_each = local.backend_envs

  statement_id  = "AllowApigwInvokeHealth-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.tamacoach_shared_backend_health.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.tamacoach_shared_backend[each.key].execution_arn}/*/*"
}

resource "aws_apigatewayv2_stage" "tamacoach_shared_backend" {
  for_each = local.backend_envs

  api_id      = aws_apigatewayv2_api.tamacoach_shared_backend[each.key].id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.tamacoach_shared_backend_apigw_access[each.key].arn
    format = jsonencode({
      requestId      = "$context.requestId"
      sourceIp       = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      responseLength = "$context.responseLength"
    })
  }

  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-backend-${each.key}-default-stage"
    Environment = each.key
  })
}

resource "aws_apigatewayv2_domain_name" "tamacoach_shared_backend" {
  for_each = local.backend_envs

  domain_name = each.value.domain

  domain_name_configuration {
    certificate_arn = local.backend_apigw_certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }

  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-backend-${each.key}-domain"
    Environment = each.key
  })
}

resource "aws_apigatewayv2_api_mapping" "tamacoach_shared_backend" {
  for_each = local.backend_envs

  api_id      = aws_apigatewayv2_api.tamacoach_shared_backend[each.key].id
  domain_name = aws_apigatewayv2_domain_name.tamacoach_shared_backend[each.key].id
  stage       = aws_apigatewayv2_stage.tamacoach_shared_backend[each.key].id
}

resource "aws_route53_record" "tamacoach_shared_backend_alias_a" {
  for_each = local.backend_envs

  zone_id = data.aws_route53_zone.tamacoach_net_backend.zone_id
  name    = each.value.domain
  type    = "A"

  alias {
    name                   = aws_apigatewayv2_domain_name.tamacoach_shared_backend[each.key].domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.tamacoach_shared_backend[each.key].domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_ssm_parameter" "tamacoach_backend_nlb_dns_name" {
  for_each = local.backend_envs

  name      = "/${var.project}/${each.key}/backend/nlb_dns_name"
  type      = "String"
  value     = aws_lb.tamacoach_shared_backend_internal[each.key].dns_name
  overwrite = true
  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-backend-${each.key}-nlb-dns-ssm"
    Environment = each.key
  })
}

resource "aws_ssm_parameter" "tamacoach_backend_target_group_arn" {
  for_each = local.backend_envs

  name      = "/${var.project}/${each.key}/backend/target_group_arn"
  type      = "String"
  value     = aws_lb_target_group.tamacoach_shared_backend[each.key].arn
  overwrite = true
  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-backend-${each.key}-tg-arn-ssm"
    Environment = each.key
  })
}

# NLB(ip target mode) -> EKS node SG: allow backend traffic on 8000.
resource "aws_vpc_security_group_ingress_rule" "tamacoach_shared_backend_nodes_from_nlb" {
  for_each = local.backend_envs

  security_group_id            = data.aws_eks_cluster.tamacoach_backend[each.key].vpc_config[0].cluster_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 8000
  to_port                      = 8000
  referenced_security_group_id = aws_security_group.tamacoach_shared_backend_nlb[each.key].id
  description                  = "Allow traffic from internal NLB (${each.key}) to backend pods on 8000"
}

resource "aws_vpc_security_group_egress_rule" "tamacoach_shared_backend_nlb_to_nodes_8000" {
  for_each = local.backend_envs

  security_group_id            = aws_security_group.tamacoach_shared_backend_nlb[each.key].id
  ip_protocol                  = "tcp"
  from_port                    = 8000
  to_port                      = 8000
  referenced_security_group_id = data.aws_eks_cluster.tamacoach_backend[each.key].vpc_config[0].cluster_security_group_id
  description                  = "Allow internal NLB (${each.key}) to EKS cluster SG on 8000"
}
