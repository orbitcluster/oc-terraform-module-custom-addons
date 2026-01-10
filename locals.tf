data "aws_partition" "current" {}

data "aws_region" "current" {}

locals {
  partition = data.aws_partition.current.partition

  # Namespaces
  istio_system_namespace = "istio-system"
  argocd_namespace       = "argocd"
  monitoring_namespace   = "monitoring"
}
