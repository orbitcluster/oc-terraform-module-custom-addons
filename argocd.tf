################################################################################
# ArgoCD
# https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd
################################################################################

resource "helm_release" "argocd" {
  count = var.enable_argocd ? 1 : 0

  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_version
  namespace  = local.argocd_namespace
  create_namespace = true

  values = [
    file("${path.module}/yamls/argocd-values.yaml")
  ]
}
