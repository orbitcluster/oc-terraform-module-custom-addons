################################################################################
# ArgoCD Spoke Role (IRSA)
# Creates an IAM role that allows the hub cluster's ArgoCD to assume
# This is only created for spoke clusters (is_hub = false)
################################################################################

data "aws_caller_identity" "current" {}

locals {
  # Use provided hub account ID or default to current account
  hub_account_id = var.hub_account_id != "" ? var.hub_account_id : data.aws_caller_identity.current.account_id

  # Construct the hub's ArgoCD role ARN using naming convention
  hub_argocd_role_arn = "arn:aws:iam::${local.hub_account_id}:role/${var.hub_cluster_name}-argocd-spoke-access"

  # Spoke role name with length validation
  spoke_role_name = "${var.cluster_name}-argocd-hub-assumable"
}

################################################################################
# IAM Role - Assumable by Hub's ArgoCD
################################################################################

resource "aws_iam_role" "argocd_hub_assumable" {
  count = var.is_hub ? 0 : 1

  name = local.spoke_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowHubArgoCD"
      Effect = "Allow"
      Principal = {
        AWS = local.hub_argocd_role_arn
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, {
    Name      = local.spoke_role_name
    Purpose   = "ArgoCD hub cluster access"
    ManagedBy = "terraform-custom-addons"
  })

  lifecycle {
    precondition {
      # If is_hub = false, hub_cluster_name must be provided
      condition     = var.is_hub || var.hub_cluster_name != ""
      error_message = "hub_cluster_name must be provided when is_hub = false"
    }
    precondition {
      condition     = length(local.spoke_role_name) <= 64
      error_message = "Spoke role name '${local.spoke_role_name}' exceeds 64 character limit (${length(local.spoke_role_name)} chars)"
    }
  }
}

################################################################################
# IAM Policy - EKS Describe (needed for K8s authentication)
################################################################################

resource "aws_iam_policy" "argocd_eks_describe" {
  count = var.is_hub ? 0 : 1

  name        = "${var.cluster_name}-argocd-eks-describe"
  description = "Allows EKS describe for ArgoCD authentication from hub cluster"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "DescribeEKS"
      Effect = "Allow"
      Action = ["eks:DescribeCluster"]
      # checkov:skip=CKV_AWS_355:EKS describe requires wildcard or specific cluster ARN
      Resource = "*"
    }]
  })

  tags = merge(var.tags, {
    Name      = "${var.cluster_name}-argocd-eks-describe"
    ManagedBy = "terraform-custom-addons"
  })
}

resource "aws_iam_role_policy_attachment" "argocd_eks_describe" {
  count = var.is_hub ? 0 : 1

  role       = aws_iam_role.argocd_hub_assumable[0].name
  policy_arn = aws_iam_policy.argocd_eks_describe[0].arn
}
