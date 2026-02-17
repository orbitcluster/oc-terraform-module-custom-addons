################################################################################
# ArgoCD Image Updater
# Automatically updates ArgoCD Applications with latest images from ECR
################################################################################

resource "helm_release" "argocd_image_updater" {
  count = var.is_hub ? 1 : 0

  name       = "argocd-image-updater"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-image-updater"
  version    = "0.9.1"
  namespace  = local.argocd_namespace

  values = [
    yamlencode({
      config = {
        registries = [
          {
            name = "ECR"
            api_url = "https://${data.aws_account.current.id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com"
            prefix = "${data.aws_account.current.id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com"
            ping = true
            # Reuse the secret managed by argocd-ecr-updater CronJob
            credentials = "secret:argocd-repo-aws-ecr-${data.aws_region.current.name}"
          }
        ]
      }
    })
  ]

  depends_on = [
    helm_release.argocd
  ]
}
