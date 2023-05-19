# http://localhost:8001/api/v1/namespaces/istio-system/services/http:kubernetes-dashboard:http/proxy/#/service?namespace=_all
# https://github.com/kubernetes/dashboard/tree/master/docs
# https://artifacthub.io/packages/helm/k8s-dashboard/kubernetes-dashboard
# Free for personal uses https://k8slens.dev/pricing.html

## Lonk https://jazzfest.link/kubedash/dashboard/assets/images/kubernetes-logo.png

locals {
  kube_dash_toleration_key = data.terraform_remote_state.eks.outputs.kube_dash_toleration_key
  kube_dash_toleration_val = data.terraform_remote_state.eks.outputs.kube_dash_toleration_val
  cluster_name             = data.terraform_remote_state.eks.outputs.cluster_id
  # namespace_kubernetes_dashboard   = "kubernetes-dashboard"
  namespace_kubernetes_dashboard   = "istio-system"
  service_account_name             = "kubernetes-dashboard"
  helm_chart_name                  = "kubernetes-dashboard"
  helm_chart_release_name          = "kubernetes-dashboard"
  helm_chart_repo                  = "https://kubernetes.github.io/dashboard"
  helm_chart_version               = "5.1.1"
  service_account_name_metr_srv    = "metrics-server"
  helm_chart_name_metr_srv         = "metrics-server"
  helm_chart_release_name_metr_srv = "metrics-server"
  helm_chart_repo_metr_srv         = "https://kubernetes-sigs.github.io/metrics-server/"
  helm_chart_version_metr_srv      = "3.7.0"
  dash_image_tag                   = "v2.3.1" # "v2.4.0"
  settings_chart_dashboard = {
    "tolerations" = [
      {
        "key"      = "${local.kube_dash_toleration_key}",
        "operator" = "Equal",
        "value"    = "${local.kube_dash_toleration_val}",
        "effect"   = "NoSchedule"
      }
    ]

    "pod_labels" = [
      {
        "app"     = local.helm_chart_release_name
        "version" = local.dash_image_tag
      }
    ]

    "commonAnnotations" = {
      "selfLink" = "/api/v1/namespaces/${local.namespace_kubernetes_dashboard}/services/kubernetes-dashboard"
    }

    "extraArgs" = [
      "--enable-insecure-login",
      "--token-ttl=6000",
      "--insecure-bind-address=0.0.0.0",
      "--insecure-port=9090"
    ]
  }
}

provider "kubernetes" {
  config_path = "~/.kube/kubeconfig-dev"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/kubeconfig-dev"
  }
}

/* resource "kubernetes_namespace" "dashboard" {
  metadata {
    name = local.namespace_kubernetes_dashboard
    annotations = {
      name            = local.namespace_kubernetes_dashboard
    }
    labels = {
      Name            = local.namespace_kubernetes_dashboard
      istio-injection = "enabled"
    }
  }
} */

## https://artifacthub.io/packages/helm/k8s-dashboard/kubernetes-dashboard
resource "helm_release" "kubernetes_dashboard" {
  name             = local.helm_chart_name
  chart            = local.helm_chart_release_name
  repository       = local.helm_chart_repo
  version          = local.helm_chart_version
  namespace        = local.namespace_kubernetes_dashboard
  create_namespace = false
  cleanup_on_fail  = false
  max_history      = 3
  recreate_pods    = true
  replace          = true
  timeout          = 180

  dynamic "set" {
    for_each = {
      "serviceAccount.name"    = local.service_account_name
      "serviceAccount.create"  = true
      "metricsScraper.enabled" = true
      "image.tag"              = local.dash_image_tag
      "protocolHttp"           = true
      "service.externalPort"   = 80
      "service.type"           = "NodePort"
    }
    content {
      name  = set.key
      value = set.value
    }
  }
  values = [
    yamlencode(local.settings_chart_dashboard)
  ]
}

## https://artifacthub.io/packages/helm/metrics-server/metrics-server
resource "helm_release" "metrics_server" {
  name             = local.helm_chart_name_metr_srv
  chart            = local.helm_chart_release_name_metr_srv
  repository       = local.helm_chart_repo_metr_srv
  version          = local.helm_chart_version_metr_srv
  namespace        = local.namespace_kubernetes_dashboard
  create_namespace = false
  cleanup_on_fail  = false
  max_history      = 3
  recreate_pods    = true
  replace          = true
  timeout          = 180

  dynamic "set" {
    for_each = {
      "serviceAccount.name"   = local.service_account_name_metr_srv
      "serviceAccount.create" = true
    }
    content {
      name  = set.key
      value = set.value
    }
  }

  values = [
    yamlencode(local.settings_chart_dashboard)
  ]
}
