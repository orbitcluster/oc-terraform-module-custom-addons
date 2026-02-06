################################################################################
# ArgoCD
# https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd
################################################################################

resource "kubernetes_namespace_v1" "argocd" {
  count = var.is_hub ? 1 : 0

  metadata {
    name = local.argocd_namespace
    labels = {
      "istio-injection" = "enabled"
    }
  }
}

resource "helm_release" "argocd" {
  count = var.is_hub ? 1 : 0

  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_version
  namespace        = local.argocd_namespace
  create_namespace = false

  values = [
    templatefile("${path.module}/yamls/argocd-values.yaml", {
      domain_url = var.domain_url
    })
  ]

  depends_on = [
    helm_release.istiod,
    kubernetes_namespace_v1.argocd
  ]
}
