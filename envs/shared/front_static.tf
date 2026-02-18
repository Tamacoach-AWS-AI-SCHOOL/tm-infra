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

  if (uri === "/") {
    request.uri = "/index.html";
    return request;
  }

  if (uri.startsWith("/stage") || uri.startsWith("/prod")) {
    if (uri.endsWith("/")) {
      request.uri = uri + "index.html";
      return request;
    }
    if (!uri.includes(".")) {
      request.uri = uri + "/index.html";
      return request;
    }
    return request;
  }

  if (uri.endsWith("/")) {
    request.uri = uri + "index.html";
    return request;
  }

  if (!uri.includes(".")) {
    request.uri = uri + "/index.html";
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
  aliases             = [var.front_alias_name]

  origin {
    domain_name              = aws_s3_bucket.tamacoach_shared_front_static.bucket_regional_domain_name
    origin_id                = "s3-${aws_s3_bucket.tamacoach_shared_front_static.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.tamacoach_shared_front_static.id
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
  zone_id = data.aws_route53_zone.tamacoach_net.zone_id
  name    = var.front_alias_name
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
