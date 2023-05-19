// https://artifacthub.io/packages/helm/bitnami/kube-state-metrics
// https://github.com/kubernetes/kube-state-metrics

locals {
  cluster_name                       = data.terraform_remote_state.eks.outputs.cluster_id
  cluster_endpoint                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_certificate_authority_data = data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data
  namespace_victoria                 = data.terraform_remote_state.victoriametrics.outputs.namespace_victoria
  tolerations_key                    = data.terraform_remote_state.victoriametrics.outputs.tolerations_key
  tolerations_value                  = data.terraform_remote_state.victoriametrics.outputs.tolerations_value
}

# Get auth token
data "aws_eks_cluster_auth" "default" {
  name = local.cluster_name
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/kubeconfig-dev"
  }
}

provider "kubernetes" {
  config_path            = "~/.kube/kubeconfig-dev"
  host                   = local.cluster_endpoint
  cluster_ca_certificate = base64decode(local.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.default.token
}

provider "kubectl" {
  host                   = local.cluster_endpoint
  cluster_ca_certificate = base64decode(local.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.default.token
  load_config_file       = false
}



resource "helm_release" "kube-state-metrics" {
  name        = var.release_name
  chart       = var.chart_name
  repository  = var.chart_repository
  version     = var.chart_version
  namespace   = local.namespace_victoria
  max_history = var.max_history

  dynamic "set" {
    for_each = {
      "tolerations[0].key"      = "${local.tolerations_key}"
      "tolerations[0].value"    = "${local.tolerations_value}"
      "tolerations[0].operator" = "Equal"
      "tolerations[0].effect"   = "NoSchedule"
      # "hostAliases[0].hostnames"             = "${var.release_name}"
    }
    content {
      name  = set.key
      value = set.value
    }
  }

  # values = [
  #   yamlencode(local.grafana_val)
  # ]

}

