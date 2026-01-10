################################################################################
# Prometheus
# https://github.com/prometheus-community/helm-charts/tree/main/charts/prometheus
################################################################################

resource "helm_release" "prometheus" {
  count = var.enable_prometheus ? 1 : 0

  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  version    = var.prometheus_version
  namespace  = local.monitoring_namespace
  create_namespace = true

  values = [
    file("${path.module}/yamls/prometheus-values.yaml")
  ]
}
