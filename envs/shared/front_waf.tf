resource "aws_wafv2_ip_set" "tamacoach_shared_front_loadtest_allowlist" {
  provider = aws.us_east_1
  count    = var.enable_front_waf && length(var.front_waf_loadtest_allowlist_cidrs) > 0 ? 1 : 0

  name               = "${local.name_prefix}-front-loadtest-allowlist"
  description        = "Temporary allowlist for controlled load testing traffic."
  scope              = "CLOUDFRONT"
  ip_address_version = "IPV4"
  addresses          = var.front_waf_loadtest_allowlist_cidrs

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-front-loadtest-allowlist"
    Service = "front"
  })
}

resource "aws_wafv2_web_acl" "tamacoach_shared_front" {
  provider = aws.us_east_1
  count    = var.enable_front_waf ? 1 : 0

  name        = "${local.name_prefix}-front-web-acl"
  description = "WAF ACL for shared CloudFront frontend distribution."
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  dynamic "rule" {
    for_each = length(var.front_waf_loadtest_allowlist_cidrs) > 0 ? [1] : []
    content {
      name     = "AllowLoadTestIps"
      priority = 1

      action {
        allow {}
      }

      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.tamacoach_shared_front_loadtest_allowlist[0].arn
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.name_prefix}-front-waf-loadtest-allow"
        sampled_requests_enabled   = true
      }
    }
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 10

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-front-waf-common"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 20

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-front-waf-known-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "RateLimitGlobalIp"
    priority = 30

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.front_waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-front-waf-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.name_prefix}-front-waf"
    sampled_requests_enabled   = true
  }

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-front-web-acl"
    Service = "front"
  })
}
