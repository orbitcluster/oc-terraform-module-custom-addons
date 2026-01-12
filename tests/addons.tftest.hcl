
run "setup" {
  module {
    source = "./tests/setup"
  }
}

run "plan" {
  command = plan

  variables {
    cluster_name                       = run.setup.cluster_name
    cluster_endpoint                   = run.setup.cluster_endpoint
    cluster_certificate_authority_data = run.setup.cluster_certificate_authority_data
    cluster_oidc_provider_arn          = run.setup.cluster_oidc_provider_arn
    cluster_oidc_issuer_url            = run.setup.cluster_oidc_issuer_url
    env                                = run.setup.env
    # vpc_id                             = run.setup.vpc_id # Custom addons dont use vpc_id currently, but keeping for consistency if needed

    # Toggles
    enable_istio      = true
    is_hub            = true
    enable_prometheus = true
    enable_grafana    = true
    enable_kiali      = true

    tags = {
      bu_id  = run.setup.bu_id
      app_id = run.setup.app_id
      env    = run.setup.env
    }
  }

  # Verify Istio resources are created
  assert {
    condition     = length(helm_release.istio_base) == 1
    error_message = "Istio Base Helm release should be created"
  }

  assert {
    condition     = length(helm_release.istiod) == 1
    error_message = "Istiod Helm release should be created"
  }

  # Verify ArgoCD resource is created
  assert {
    condition     = length(helm_release.argocd) == 1
    error_message = "ArgoCD Helm release should be created"
  }

  # Verify Prometheus resource is created
  assert {
    condition     = length(helm_release.prometheus) == 1
    error_message = "Prometheus Helm release should be created"
  }

  # Verify Grafana resource is created
  assert {
    condition     = length(helm_release.grafana) == 1
    error_message = "Grafana Helm release should be created"
  }

  # Verify Kiali resource is created
  assert {
    condition     = length(helm_release.kiali) == 1
    error_message = "Kiali Helm release should be created"
  }
}
