################################################################################
# External Secrets Operator (ESO)
################################################################################

locals {
  eso_namespace           = "external-secrets"
  eso_serviceaccount_name = "eso-service-account"

  eso_role_name = "eso-spoke-ecr-role"
}

################################################################################
# 1. IAM Role for Service Accounts (IRSA) for Spoke clusters
################################################################################

resource "aws_iam_role" "eso_hub_ecr_role" {
  count = !var.is_hub ? 1 : 0

  name = local.eso_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = var.cluster_oidc_provider_arn
        }
        Condition = {
          "StringEquals" = {
            "${replace(var.cluster_oidc_issuer_url, "https://", "")}:sub" : "system:serviceaccount:${local.eso_namespace}:${local.eso_serviceaccount_name}",
            "${replace(var.cluster_oidc_issuer_url, "https://", "")}:aud" : "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name      = local.eso_role_name
    Purpose   = "ESO Hub ECR Pull IRSA"
    ManagedBy = "terraform-custom-addons"
  })

  lifecycle {
    precondition {
      # If setup_hub_ecr_pull = true, hub_account_id must be provided
      condition     = var.hub_account_id != ""
      error_message = "hub_account_id must be provided when enable_eso is true on a spoke cluster."
    }
  }
}

resource "aws_iam_policy" "eso_ecr_pull" {
  count = !var.is_hub ? 1 : 0

  name        = "${var.cluster_name}-eso-assume-ecr-hub"
  description = "Allows assuming the ecr-hub-role in the hub account for ECR access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = ["sts:AssumeRole"]
        Effect = "Allow"
        # Since ecr_hub_role_name in hub is now strictly "ecr-hub-role" (based on your recent change)
        Resource = "arn:aws:iam::${var.hub_account_id}:role/ecr-hub-role"
      }
    ]
  })

  tags = merge(var.tags, {
    Name      = "${var.cluster_name}-eso-assume-ecr-hub-policy"
    ManagedBy = "terraform-custom-addons"
  })
}

resource "aws_iam_role_policy_attachment" "eso_ecr_pull_attachment" {
  count = !var.is_hub ? 1 : 0

  role       = aws_iam_role.eso_hub_ecr_role[0].name
  policy_arn = aws_iam_policy.eso_ecr_pull[0].arn
}

################################################################################
# 2. Kubernetes Namespace creation
################################################################################

resource "kubernetes_namespace" "eso" {
  count = !var.is_hub ? 1 : 0

  metadata {
    name = local.eso_namespace
    labels = {
      name = local.eso_namespace
    }
  }
}

################################################################################
# 3. Helm Release - External Secrets Operator
################################################################################

resource "helm_release" "external_secrets" {
  count = !var.is_hub ? 1 : 0

  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = var.eso_helm_version
  namespace  = kubernetes_namespace.eso[0].metadata[0].name

  values = [
    templatefile("${path.module}/yamls/external-secrets-values.yaml", {
      eso_irsa_arn_annotation = !var.is_hub ? jsonencode({
        "eks.amazonaws.com/role-arn" = aws_iam_role.eso_hub_ecr_role[0].arn
      }) : "{}"
    })
  ]

  depends_on = [
    kubernetes_namespace.eso
  ]
}

resource "time_sleep" "wait_for_eso_crds" {
  count = !var.is_hub ? 1 : 0

  depends_on = [helm_release.external_secrets]

  create_duration = "30s"
}

################################################################################
# 4. ESO Custom Resources (for Token Generation and Distribution)
# Note: These are only created on Spoke clusters pulling from Hub ECR.
################################################################################

resource "kubectl_manifest" "eso_ecr_auth_token" {
  count = !var.is_hub ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: generators.external-secrets.io/v1alpha1
    kind: ClusterGenerator
    metadata:
      name: hub-ecr-token-gen
    spec:
      kind: ECRAuthorizationToken
      generator:
        region: ${data.aws_region.current.name}
  YAML

  depends_on = [
    time_sleep.wait_for_eso_crds
  ]
}

resource "kubectl_manifest" "eso_external_secret" {
  count = !var.is_hub ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: external-secrets.io/v1
    kind: ExternalSecret
    metadata:
      name: hub-ecr-docker-secret
      namespace: ${local.eso_namespace}
    spec:
      refreshInterval: "1h"
      target:
        name: hub-ecr-docker-secret
        template:
          type: kubernetes.io/dockerconfigjson
          data:
            .dockerconfigjson: '{"auths": {"${var.hub_account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com": {"username": "AWS", "password": "{{ .password }}"}}}'
      dataFrom:
      - sourceRef:
          generatorRef:
            apiVersion: generators.external-secrets.io/v1alpha1
            kind: ClusterGenerator
            name: hub-ecr-token-gen
  YAML

  depends_on = [
    kubectl_manifest.eso_ecr_auth_token,
    time_sleep.wait_for_eso_crds
  ]
}

resource "kubectl_manifest" "eso_cluster_external_secret" {
  count = !var.is_hub ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: external-secrets.io/v1
    kind: ClusterExternalSecret
    metadata:
      name: distribute-hub-ecr-secret
    spec:
      externalSecretName: hub-ecr-docker-secret
      namespaceSelector:
        matchLabels:
          allow-hub-ecr-pull: "true"
      externalSecretSpec:
        refreshInterval: "1h"
        target:
          name: hub-ecr-docker-secret
          template:
            type: kubernetes.io/dockerconfigjson
            data:
              .dockerconfigjson: '{"auths": {"${var.hub_account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com": {"username": "AWS", "password": "{{ .password }}"}}}'
        dataFrom:
        - sourceRef:
            generatorRef:
              apiVersion: generators.external-secrets.io/v1alpha1
              kind: ClusterGenerator
              name: hub-ecr-token-gen
  YAML

  depends_on = [
    kubectl_manifest.eso_external_secret,
    time_sleep.wait_for_eso_crds
  ]
}
