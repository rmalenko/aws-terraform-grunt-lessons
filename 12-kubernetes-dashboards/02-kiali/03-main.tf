# kubectl port-forward svc/kiali 20001:20001 -n istio-system &
# https://localhost:20001
# kubectl get secret -n istio-system $(kubectl get sa kiali -n istio-system -o jsonpath={.secrets[0].name}) -o jsonpath={.data.token} | base64 -d
# https://github.com/kiali/helm-charts/blob/master/kiali-server/values.yaml
# https://kiali.io/docs/configuration/authentication/

locals {
  kube_dash_toleration_key = data.terraform_remote_state.eks.outputs.kube_dash_toleration_key
  kube_dash_toleration_val = data.terraform_remote_state.eks.outputs.kube_dash_toleration_val
  namespace                = data.terraform_remote_state.namespace_kube_dashb.outputs.namespace_kubernetes_dashboard
  istio_namespace          = data.terraform_remote_state.istio.outputs.istio_namespace

  helm_chart_name_kiali         = "kiali-server"
  helm_chart_release_name_kiali = "kiali-server"
  helm_chart_repo_kiali         = "https://kiali.org/helm-charts"
  helm_chart_version_kiali      = "1.37.0"

  helm_chart_name_operator         = "kiali-operator"
  helm_chart_release_name_operator = "kiali-operator"
  helm_chart_repo_operator         = "https://kiali.org/helm-charts"
  helm_chart_version_operator      = "1.37.0"

  helm_wait_tiimeout = 300

  kiali_server_values = {
    istio_namespace    = local.istio_namespace
    HELM_IMAGE_TAG     = "v1.45.0" # version like "v1.39" (see: https://quay.io/repository/kiali/kiali?tab=tags) or a digest hash
    nodeSelector_key   = "${local.kube_dash_toleration_key}",
    nodeSelector_value = "${local.kube_dash_toleration_val}",
  }

  settings_chart = {
    "tolerations" : [
      {
        "key" : "${local.kube_dash_toleration_key}",
        "value" : "${local.kube_dash_toleration_val}",
        "effect" : "NoSchedule",
        "operator" : "Equal"
      }
    ]
    "pod_labels" : [
      {
        "app"     = local.helm_chart_name_kiali
        "version" = lookup(local.kiali_server_values, "HELM_IMAGE_TAG", "v1.45.0")
      }
    ]
  }
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/kubeconfig-dev"
  }
}

resource "helm_release" "kiali_operator" {
  name       = local.helm_chart_name_operator
  chart      = local.helm_chart_release_name_operator
  repository = local.helm_chart_repo_operator
  # version          = local.helm_chart_version_operator
  # namespace        = local.namespace
  namespace        = local.istio_namespace
  cleanup_on_fail  = false
  create_namespace = false
  max_history      = 3
  recreate_pods    = true
  replace          = true
  timeout          = 180

  dynamic "set" {
    for_each = {
      "cr.create"     = false
      "auth.strategy" = "token"
    }
    content {
      name  = set.key
      value = set.value
    }
  }

  values = [
    yamlencode(local.settings_chart)
  ]

}


resource "helm_release" "kiali-server" {
  name       = local.helm_chart_name_kiali
  chart      = local.helm_chart_release_name_kiali
  repository = local.helm_chart_repo_kiali
  # version          = local.helm_chart_version_kiali
  # namespace        = local.namespace
  namespace        = local.istio_namespace
  create_namespace = false
  wait             = true
  timeout          = local.helm_wait_tiimeout
  cleanup_on_fail  = false
  force_update     = true
  recreate_pods    = true
  replace          = true
  max_history      = "5"
  values = [
    templatefile("${path.module}/templates/kiali-server-values.yml", local.kiali_server_values),
  ]
}