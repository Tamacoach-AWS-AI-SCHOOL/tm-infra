data "aws_route53_zone" "tamacoach_net" {
  name         = "tamacoach.net"
  private_zone = false
}

resource "aws_acm_certificate" "tamacoach_shared_cloudfront" {
  provider                  = aws.us_east_1
  domain_name               = "*.tamacoach.net"
  subject_alternative_names = ["tamacoach.net"]
  validation_method         = "DNS"
}

resource "aws_route53_record" "tamacoach_shared_cloudfront_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.tamacoach_shared_cloudfront.domain_validation_options :
    dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }

  zone_id         = data.aws_route53_zone.tamacoach_net.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.value]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "tamacoach_shared_cloudfront" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.tamacoach_shared_cloudfront.arn
  validation_record_fqdns = [for record in aws_route53_record.tamacoach_shared_cloudfront_cert_validation : record.fqdn]
}

resource "aws_acm_certificate" "tamacoach_shared_apigw" {
  domain_name               = "api.tamacoach.net"
  subject_alternative_names = ["api-stage.tamacoach.net"]
  validation_method         = "DNS"
}

resource "aws_route53_record" "tamacoach_shared_apigw_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.tamacoach_shared_apigw.domain_validation_options :
    dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }

  zone_id         = data.aws_route53_zone.tamacoach_net.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.value]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "tamacoach_shared_apigw" {
  certificate_arn         = aws_acm_certificate.tamacoach_shared_apigw.arn
  validation_record_fqdns = [for record in aws_route53_record.tamacoach_shared_apigw_cert_validation : record.fqdn]
}

resource "aws_acm_certificate" "tamacoach_shared_argocd" {
  domain_name               = "argocd.tamacoach.net"
  subject_alternative_names = ["argocd-dev.tamacoach.net"]
  validation_method         = "DNS"
}

resource "aws_route53_record" "tamacoach_shared_argocd_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.tamacoach_shared_argocd.domain_validation_options :
    dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }

  zone_id         = data.aws_route53_zone.tamacoach_net.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.value]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "tamacoach_shared_argocd" {
  certificate_arn         = aws_acm_certificate.tamacoach_shared_argocd.arn
  validation_record_fqdns = [for record in aws_route53_record.tamacoach_shared_argocd_cert_validation : record.fqdn]
}
