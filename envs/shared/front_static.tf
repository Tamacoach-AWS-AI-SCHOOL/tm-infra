locals {
  front_bucket_name = "${local.name_prefix}-front-static-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket" "tamacoach_shared_front_static" {
  bucket = local.front_bucket_name
  tags   = local.common_tags
}

resource "aws_s3_bucket_public_access_block" "tamacoach_shared_front_static" {
  bucket = aws_s3_bucket.tamacoach_shared_front_static.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "tamacoach_shared_front_static" {
  bucket = aws_s3_bucket.tamacoach_shared_front_static.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_cloudfront_origin_access_control" "tamacoach_shared_front_static" {
  name                              = "${local.name_prefix}-front-oac"
  description                       = "OAC for ${local.name_prefix} static frontend bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_function" "tamacoach_shared_front_rewrite" {
  name    = "${local.name_prefix}-front-rewrite"
  runtime = "cloudfront-js-1.0"
  publish = true
  comment = "Rewrite SPA routes and stage/prod paths to index.html"
  code    = <<-EOF
function handler(event) {
    var request = event.request;
    var uri = request.uri;
    var host = request.headers.host.value;

    // API 요청은 CloudFront API behavior로 전달하고 SPA rewrite에서 제외
    if (uri === "/api" || uri.startsWith("/api/")) {
        return request;
    }

    // 1. 도메인에 따른 환경(Prefix) 결정
    var prefix = "/prod";
    if (host === "stage.tamacoach.net") {
        prefix = "/stage";
    }

    // 2. 이미 환경 경로(/prod, /stage)가 포함된 요청인지 확인
    if (uri.startsWith("/prod") || uri.startsWith("/stage")) {
        // 경로 끝이 / 이면 index.html 추가
        if (uri.endsWith("/")) {
            request.uri = uri + "index.html";
        } 
        // 확장자가 없는 경로면 /index.html 추가 (SPA 대응)
        else if (!uri.includes(".")) {
            request.uri = uri + "/index.html";
        }
        return request;
    }

    // 3. 환경 경로가 없는 요청에 prefix 추가 및 index.html 처리
    if (uri === "/") {
        request.uri = prefix + "/index.html";
    } else if (uri.endsWith("/")) {
        request.uri = prefix + uri + "index.html";
    } else if (!uri.includes(".")) {
        request.uri = prefix + uri + "/index.html";
    } else {
        request.uri = prefix + uri;
    }

    return request;
}
EOF
}

resource "aws_cloudfront_distribution" "tamacoach_shared_front_static" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${local.name_prefix} static frontend"
  default_root_object = "index.html"
  aliases             = ["tamacoach.net", "app.tamacoach.net", "stage.tamacoach.net"]

  origin {
    domain_name              = aws_s3_bucket.tamacoach_shared_front_static.bucket_regional_domain_name
    origin_id                = "s3-${aws_s3_bucket.tamacoach_shared_front_static.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.tamacoach_shared_front_static.id
  }

  origin {
    domain_name = "api-stage.tamacoach.net"
    origin_id   = "api-stage-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  origin {
    domain_name = "api.tamacoach.net"
    origin_id   = "api-prod-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  ordered_cache_behavior {
    # /api requests are routed to an API origin, and Lambda@Edge picks stage/prod by Host.
    path_pattern     = "/api*"
    target_origin_id = "api-prod-origin"

    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    compress               = true

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0

    forwarded_values {
      query_string = true
      headers      = ["*"]
      cookies {
        forward = "all"
      }
    }

    lambda_function_association {
      event_type   = "origin-request"
      lambda_arn   = aws_lambda_function.tamacoach_shared_front_api_origin_router.qualified_arn
      include_body = false
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3-${aws_s3_bucket.tamacoach_shared_front_static.id}"

    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.tamacoach_shared_front_rewrite.arn
    }

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.front_acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = local.common_tags
}

data "archive_file" "tamacoach_shared_front_api_origin_router" {
  type        = "zip"
  source_file = "${path.module}/lambda/front_api_origin_router/index.js"
  output_path = "${path.module}/lambda/front_api_origin_router/index.zip"
}

resource "aws_iam_role" "tamacoach_shared_front_api_origin_router" {
  provider = aws.us_east_1
  name     = "${local.name_prefix}-front-api-origin-router-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = ["lambda.amazonaws.com", "edgelambda.amazonaws.com"]
      }
    }]
  })

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-front-api-origin-router-role"
  })
}

resource "aws_iam_role_policy_attachment" "tamacoach_shared_front_api_origin_router_basic" {
  provider   = aws.us_east_1
  role       = aws_iam_role.tamacoach_shared_front_api_origin_router.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "tamacoach_shared_front_api_origin_router" {
  provider         = aws.us_east_1
  function_name    = "${local.name_prefix}-front-api-origin-router"
  role             = aws_iam_role.tamacoach_shared_front_api_origin_router.arn
  handler          = "index.handler"
  runtime          = "nodejs18.x"
  filename         = data.archive_file.tamacoach_shared_front_api_origin_router.output_path
  source_code_hash = data.archive_file.tamacoach_shared_front_api_origin_router.output_base64sha256
  publish          = true
  timeout          = 5

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-front-api-origin-router"
  })

  depends_on = [aws_iam_role_policy_attachment.tamacoach_shared_front_api_origin_router_basic]
}

resource "aws_s3_bucket_policy" "tamacoach_shared_front_static" {
  bucket = aws_s3_bucket.tamacoach_shared_front_static.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipalReadOnly"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = ["s3:GetObject"]
        Resource  = "${aws_s3_bucket.tamacoach_shared_front_static.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.tamacoach_shared_front_static.arn
          }
        }
      }
    ]
  })
}

resource "aws_route53_record" "tamacoach_shared_front_alias_a" {
  for_each = toset(["tamacoach.net", "app.tamacoach.net", "stage.tamacoach.net"])

  zone_id = data.aws_route53_zone.tamacoach_net.zone_id
  name    = each.value
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.tamacoach_shared_front_static.domain_name
    zone_id                = aws_cloudfront_distribution.tamacoach_shared_front_static.hosted_zone_id
    evaluate_target_health = false
  }
}

check "front_zone_id_matches" {
  assert {
    condition     = data.aws_route53_zone.tamacoach_net.zone_id == var.front_route53_zone_id
    error_message = "front_route53_zone_id must match the tamacoach.net hosted zone id."
  }
}
