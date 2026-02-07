################################################################################
# Grafana
# https://github.com/grafana/helm-charts/tree/main/charts/grafana
################################################################################

locals {
  # ArgoCD dashboard configuration - only included for hub clusters
  argocd_dashboard = var.is_hub ? {
    argocd = {
      gnetId     = 14584
      revision   = 1
      datasource = "Prometheus"
    }
  } : {}
}

resource "helm_release" "grafana" {
  count = var.enable_grafana ? 1 : 0

  name             = "grafana"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "grafana"
  version          = var.grafana_version
  namespace        = local.monitoring_namespace
  create_namespace = false

  values = [
    templatefile("${path.module}/yamls/grafana-values.yaml", {
      domain_url = var.domain_url
    }),
    # Conditionally add ArgoCD dashboard for hub clusters
    var.is_hub ? yamlencode({
      dashboards = {
        default = local.argocd_dashboard
      }
    }) : ""
  ]

  depends_on = [
    helm_release.istiod,
    kubernetes_namespace_v1.monitoring,
    helm_release.prometheus
  ]
}
