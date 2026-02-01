# ArgoCD VirtualService
resource "kubernetes_manifest" "argocd_vs" {
  manifest = {
    apiVersion = "networking.istio.io/v1beta1"
    kind       = "VirtualService"
    metadata = {
      name      = "argocd-vs"
      namespace = local.argocd_namespace
    }
    spec = {
      hosts    = ["orbitcluster.platform.com"]
      gateways = ["${local.istio_system_namespace}/istio-gateway"]
      http = [
        {
          match = [
            {
              uri = {
                prefix = "/argocd"
              }
            }
          ]
          route = [
            {
              destination = {
                host = "argocd-server"
                port = {
                  number = 80
                }
              }
            }
          ]
        }
      ]
    }
  }
  depends_on = [helm_release.argocd, kubernetes_manifest.istio_gateway]
}

# Grafana VirtualService
resource "kubernetes_manifest" "grafana_vs" {
  manifest = {
    apiVersion = "networking.istio.io/v1beta1"
    kind       = "VirtualService"
    metadata = {
      name      = "grafana-vs"
      namespace = local.monitoring_namespace
    }
    spec = {
      hosts    = ["orbitcluster.platform.com"]
      gateways = ["${local.istio_system_namespace}/istio-gateway"]
      http = [
        {
          match = [
            {
              uri = {
                prefix = "/grafana"
              }
            }
          ]
          route = [
            {
              destination = {
                host = "grafana"
                port = {
                  number = 80
                }
              }
            }
          ]
        }
      ]
    }
  }
  depends_on = [helm_release.grafana, kubernetes_manifest.istio_gateway]
}

# Kiali VirtualService
resource "kubernetes_manifest" "kiali_vs" {
  manifest = {
    apiVersion = "networking.istio.io/v1beta1"
    kind       = "VirtualService"
    metadata = {
      name      = "kiali-vs"
      namespace = local.istio_system_namespace
    }
    spec = {
      hosts    = ["orbitcluster.platform.com"]
      gateways = ["${local.istio_system_namespace}/istio-gateway"]
      http = [
        {
          match = [
            {
              uri = {
                prefix = "/kiali"
              }
            }
          ]
          route = [
            {
              destination = {
                host = "kiali"
                port = {
                  number = 20001
                }
              }
            }
          ]
        }
      ]
    }
  }
  depends_on = [helm_release.kiali, kubernetes_manifest.istio_gateway]
}

# Prometheus VirtualService
resource "kubernetes_manifest" "prometheus_vs" {
  manifest = {
    apiVersion = "networking.istio.io/v1beta1"
    kind       = "VirtualService"
    metadata = {
      name      = "prometheus-vs"
      namespace = local.monitoring_namespace
    }
    spec = {
      hosts    = ["orbitcluster.platform.com"]
      gateways = ["${local.istio_system_namespace}/istio-gateway"]
      http = [
        {
          match = [
            {
              uri = {
                prefix = "/prometheus"
              }
            }
          ]
          route = [
            {
              destination = {
                host = "prometheus-server"
                port = {
                  number = 80
                }
              }
            }
          ]
        }
      ]
    }
  }
  depends_on = [helm_release.prometheus, kubernetes_manifest.istio_gateway]
}
