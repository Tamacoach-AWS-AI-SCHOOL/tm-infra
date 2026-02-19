locals {
  argocd_ingress_name            = "argocd-${var.env}-${var.project}"
  argocd_acm_certificate_arn_ref = var.argocd_acm_certificate_arn != "" ? var.argocd_acm_certificate_arn : try(data.terraform_remote_state.network.outputs.argocd_certificate_arn, "")
  argocd_ingress_hostname        = try(kubernetes_ingress_v1.argocd_ingress.status[0].load_balancer[0].ingress[0].hostname, null)
}

data "aws_route53_zone" "tamacoach_net_argocd" {
  name         = "tamacoach.net"
  private_zone = false
}

check "argocd_ingress_cert_arn_required" {
  assert {
    condition     = local.argocd_acm_certificate_arn_ref != ""
    error_message = "Set argocd_acm_certificate_arn or apply envs/shared to publish output.argocd_certificate_arn."
  }
}

resource "kubernetes_ingress_v1" "argocd_ingress" {
  wait_for_load_balancer = true

  metadata {
    name      = local.argocd_ingress_name
    namespace = var.argocd_namespace
    annotations = {
      "alb.ingress.kubernetes.io/scheme"          = var.argocd_ingress_scheme
      "alb.ingress.kubernetes.io/target-type"     = "ip"
      "alb.ingress.kubernetes.io/listen-ports"    = "[{\"HTTPS\":443}]"
      "alb.ingress.kubernetes.io/certificate-arn" = local.argocd_acm_certificate_arn_ref
      "alb.ingress.kubernetes.io/ssl-redirect"    = "443"
      "alb.ingress.kubernetes.io/inbound-cidrs"   = join(",", var.argocd_ingress_allowed_cidrs)
    }
  }

  spec {
    ingress_class_name = "alb"

    rule {
      host = var.argocd_domain_name

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "argocd-server"

              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.argocd,
  ]
}

resource "aws_route53_record" "argocd_cname" {
  for_each = local.argocd_ingress_hostname == null ? {} : { main = local.argocd_ingress_hostname }

  zone_id = data.aws_route53_zone.tamacoach_net_argocd.zone_id
  name    = var.argocd_domain_name
  type    = "CNAME"
  ttl     = 300
  records = [
    each.value,
  ]
}
