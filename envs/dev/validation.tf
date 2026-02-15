resource "kubernetes_persistent_volume_claim_v1" "gp3_test" {
  count = var.enable_validation_resources ? 1 : 0

  metadata {
    name      = "gp3-test-pvc"
    namespace = "default"
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "gp3"

    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}

resource "kubernetes_namespace_v1" "lbc_test" {
  count = var.enable_validation_resources ? 1 : 0

  metadata {
    name = "lbc-test"
  }
}

resource "kubernetes_deployment_v1" "web" {
  count = var.enable_validation_resources ? 1 : 0

  metadata {
    name      = "web"
    namespace = kubernetes_namespace_v1.lbc_test[0].metadata[0].name
    labels = {
      app = "web"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "web"
      }
    }

    template {
      metadata {
        labels = {
          app = "web"
        }
      }

      spec {
        container {
          name  = "nginx"
          image = "nginx:1.27"

          port {
            container_port = 80
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "web_lb" {
  count = var.enable_validation_resources ? 1 : 0

  metadata {
    name      = "web"
    namespace = kubernetes_namespace_v1.lbc_test[0].metadata[0].name
    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
    }
  }

  spec {
    selector = {
      app = "web"
    }

    port {
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }

    type = "LoadBalancer"
  }
}
