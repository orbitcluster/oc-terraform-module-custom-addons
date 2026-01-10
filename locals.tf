data "aws_partition" "current" {}

data "aws_region" "current" {}

locals {
  partition = data.aws_partition.current.partition

  # Extract OIDC issuer ID from the URL
  oidc_issuer_id = replace(var.cluster_oidc_issuer_url, "https://", "")

  # Common labels for Helm releases
  common_labels = merge(var.tags, {
    "app.kubernetes.io/managed-by" = "terraform"
    "cluster"                      = var.cluster_name
  })

  # Namespaces
  istio_system_namespace = "istio-system"
  argocd_namespace       = "argocd"
  monitoring_namespace   = "monitoring"
}
