resource "aws_wafv2_web_acl" "tamacoach_shared_front" {
  provider = aws.us_east_1
  count    = var.enable_front_waf ? 1 : 0

  name        = "${local.name_prefix}-front-web-acl"
  description = "WAF ACL for shared CloudFront frontend distribution."
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
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
