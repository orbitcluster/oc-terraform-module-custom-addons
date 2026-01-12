################################################################################
# Grafana
# https://github.com/grafana/helm-charts/tree/main/charts/grafana
################################################################################

resource "helm_release" "grafana" {
  count = var.enable_grafana ? 1 : 0

  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  version    = var.grafana_version
  namespace  = local.monitoring_namespace
  create_namespace = false

  values = [
    file("${path.module}/yamls/grafana-values.yaml")
  ]

  depends_on = [
    helm_release.istiod,
    kubernetes_namespace_v1.monitoring,
    helm_release.prometheus
  ]
}
