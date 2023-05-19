# https://artifacthub.io/packages/helm/victoriametrics/victoria-metrics-cluster

locals {
  namespace                          = "kube-system"
  namespace_victoria                 = "victoriametrics"
  cluster_certificate_authority_data = data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data
  cluster_name                       = data.terraform_remote_state.eks.outputs.cluster_id
  cluster_endpoint                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_oidc_issuer_url            = data.terraform_remote_state.eks.outputs.cluster_oidc_issuer_url
  oidc_arn                           = data.terraform_remote_state.eks.outputs.oidc_provider_arn
  kubernetes_storage_class_name      = data.terraform_remote_state.efs_csi_driver.outputs.kubernetes_storage_class
  size_of_persistent_volume_claim    = "50Gi"
  name_persistent_volume_claim       = "victoria-metrics"
  eks_iput_target                    = data.terraform_remote_state.efs-nfs.outputs.dns_of_efs_mount_target
  vm-alerts-conf-map-name            = "victoria-alerts-config-map"
  alertmanager-conf-map-name         = "alertmanager"
  tolerations_key                    = "k8s-app"
  tolerations_value                  = "victoriametrics"
  aws_template_name_karpenter        = data.terraform_remote_state.karpenter_and_launch_template.outputs.aws_template_name_karpenter
  instance_name                      = "victoria-metrics-karpenter"
  helm_wait_tiimeout                 = 600
  helm_wait_if                       = true # or false

  victoria_helm_values = {
    "server_persistentVolume_enabled"       = true
    "server_persistentVolume_storageClass"  = local.kubernetes_storage_class_name
    "server_persistentVolume_size"          = local.size_of_persistent_volume_claim
    "server_persistentVolume_existingClaim" = local.name_persistent_volume_claim
    "aws_region"                            = var.aws_region
    "access_key"                            = aws_iam_access_key.victoriametrics.id
    "secret_key"                            = aws_iam_access_key.victoriametrics.secret
    "role_arn"                              = aws_iam_role.victoria_read_ec2.arn
  }

  victoria-metrics-helm-alert-values = {
    "server_name"               = "server"
    "datasource_url"            = "http://victoria-metrics-single-server:8428"
    "notifier_alertmanager_url" = "http://victoria-metrics-alert-alertmanager:9093"
  }

  slack                            = {}
  victoria-alerts-config-map-rules = {}

  # api_url_ vars gets from "${get_env("HOME")}/.aws/additional.tfvars". Looks at terragrunt.hcl file.
  alertmanager = {
    "api_url_critical" = var.api_url_critical
    "api_url_warning"  = var.api_url_warning
    "critical_channel" = "#alert-manager-critical"
    "warning_channel"  = "#alert-manager-warning"
  }

  tags = {
    Name = local.cluster_name
  }
  vm-single-ver = "0.8.30"
  vm-alert-ver  = "0.4.32"

}

resource "null_resource" "victoria-metrics-alert" {
  provisioner "local-exec" {
    command = <<EOF
    set -xe
    cd ${path.root}
    rm -rf ./${local.vm-alert-ver} || true
    wget https://victoriametrics.github.io/helm-charts/packages/victoria-metrics-alert-${local.vm-alert-ver}.tgz && tar -xvzf victoria-metrics-alert-${local.vm-alert-ver}.tgz
    EOF
  }
  triggers = {
    build_number = local.vm-alert-ver
  }
}

resource "null_resource" "victoria-metrics-single" {
  provisioner "local-exec" {
    command = <<EOF
    set -xe
    cd ${path.root}
    rm -rf ./${local.vm-single-ver} || true
    wget https://victoriametrics.github.io/helm-charts/packages/victoria-metrics-single-${local.vm-single-ver}.tgz && tar -xvzf victoria-metrics-single-${local.vm-single-ver}.tgz
    EOF
  }
  triggers = {
    build_number = local.vm-single-ver
  }
}

# https://victoriametrics.github.io/helm-charts/packages/victoria-metrics-single-${local.vm-single-ver}.tgz
# https://victoriametrics.github.io/helm-charts/packages/victoria-metrics-alert-${local.vm-alert-ver}.tgz

resource "kubernetes_namespace" "victoriametrics" {
  metadata {
    name = local.namespace_victoria
    annotations = {
      name            = local.namespace_victoria
      istio-injection = "enabled"
    }
    labels = {
      Name                                      = local.namespace_victoria
      purpose                                   = local.namespace_victoria
      istio-injection                           = "enabled"
      "elbv2.k8s.aws/pod-readiness-gate-inject" = "enabled"
    }
  }
}

data "aws_eks_cluster_auth" "default" {
  name = local.cluster_name
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

provider "helm" {
  kubernetes {
    config_path = "~/.kube/kubeconfig-dev"
  }
}

resource "helm_release" "victoria_metrics" {
  name       = var.vm_release_name
  chart      = var.vm_chart
  repository = var.vm_chart_repository_url
  # version     = var.vm_chart_version
  namespace   = local.namespace_victoria
  max_history = var.max_history
  wait        = local.helm_wait_if
  timeout     = local.helm_wait_tiimeout

  dynamic "set" {
    for_each = {
      "rbac.create"                             = true
      "server.tolerations[0].key"               = local.tolerations_key
      "server.tolerations[0].value"             = local.tolerations_value
      "server.tolerations[0].operator"          = "Equal"
      "server.tolerations[0].effect"            = "NoSchedule"
      "server.retentionPeriod"                  = 6 ## months
      "server.persistentVolume.enabled"         = true
      "server.persistentVolume.storageClass"    = local.kubernetes_storage_class_name
      "server.persistentVolume.size"            = local.size_of_persistent_volume_claim
      "server.persistentVolume.existingClaim"   = local.name_persistent_volume_claim
      "server.scrape.enabled"                   = true
      "server.extraArgs.enableTCP6"             = "false"
      "server.extraArgs.maxLabelsPerTimeseries" = 50
      # "server.extraArgs.storageDataPath"        = "/victoriametrics_data" # doesn't work due to wrong helm template https://github.com/VictoriaMetrics/helm-charts/issues/297
    }
    content {
      name  = set.key
      value = set.value
    }
  }

  # values = [
  #   yamlencode(local.victoria_values)
  # ]

  values = [
    templatefile("${path.module}/templates/victoria_helm_values.yaml", local.victoria_helm_values),
  ]

  depends_on = [kubectl_manifest.karpenter_provisioner]

}

resource "kubernetes_persistent_volume" "victoriastore" {
  metadata {
    name = local.name_persistent_volume_claim
    labels = {
      Name    = "victoriastore"
      purpose = "victoriastore"
    }
  }
  spec {
    storage_class_name               = local.kubernetes_storage_class_name
    persistent_volume_reclaim_policy = "Retain"
    volume_mode                      = "Filesystem"
    access_modes                     = ["ReadWriteMany"]
    mount_options                    = ["nfsvers=4.1"]

    capacity = {
      storage = local.size_of_persistent_volume_claim
    }

    persistent_volume_source {
      nfs {
        path   = "/"
        server = local.eks_iput_target
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "victoriastore" {
  wait_until_bound = true

  metadata {
    name      = local.name_persistent_volume_claim
    namespace = local.namespace_victoria
    annotations = {
      Description = "Volume for victoriastore DB"
    }
    labels = {
      Name                                      = "victoriastore"
      purpose                                   = "victoriastore"
      "elbv2.k8s.aws/pod-readiness-gate-inject" = "enabled"
    }
  }

  spec {
    access_modes       = ["ReadWriteMany"]
    storage_class_name = local.kubernetes_storage_class_name
    volume_name        = kubernetes_persistent_volume.victoriastore.metadata.0.name

    resources {
      requests = {
        storage = local.size_of_persistent_volume_claim
      }
      limits = {
        storage = local.size_of_persistent_volume_claim
      }
    }
  }
  timeouts {
    create = "5m"
  }
}


resource "kubernetes_config_map" "victoria_alerts" {
  metadata {
    name      = local.vm-alerts-conf-map-name
    namespace = local.namespace_victoria
  }
  data = {
    "alert-rules.yaml" = "${templatefile("${path.module}/templates/victoria-alerts-config-map-rules.yaml", local.victoria-alerts-config-map-rules)}"
  }
}

resource "kubernetes_config_map" "alertmanager" {
  metadata {
    name      = local.alertmanager-conf-map-name
    namespace = local.namespace_victoria
  }
  data = {
    "alertmanager.yaml"    = "${templatefile("${path.module}/templates/alertmanager.yaml", local.alertmanager)}"
    "slack-templates.tmpl" = "${templatefile("${path.module}/templates/slack-templates.tmpl", local.slack)}"
  }
}


resource "helm_release" "victoria_alerts" {
  name       = var.vm_release_name_alerts
  chart      = var.vm_chart_alerts
  repository = var.vm_chart_repository_url
  # version     = var.vm_chart_version_alerts
  namespace   = local.namespace_victoria
  max_history = var.max_history
  wait        = local.helm_wait_if
  timeout     = local.helm_wait_tiimeout

  dynamic "set" {
    for_each = {
      "rbac.create" = true

      "server.tolerations[0].key"      = local.tolerations_key
      "server.tolerations[0].value"    = local.tolerations_value
      "server.tolerations[0].operator" = "Equal"
      "server.tolerations[0].effect"   = "NoSchedule"
      "server.replicaCount"            = 1
      "server.configMap"               = "${local.vm-alerts-conf-map-name}"
      # "server.image.tag"               = "v1.75.1"


      "alertmanager.enabled"                 = true
      "alertmanager.replicaCount"            = 1
      "alertmanager.tolerations[0].key"      = local.tolerations_key
      "alertmanager.tolerations[0].value"    = local.tolerations_value
      "alertmanager.tolerations[0].operator" = "Equal"
      "alertmanager.tolerations[0].effect"   = "NoSchedule"
      "alertmanager.configMap"               = "${local.alertmanager-conf-map-name}"
      # "alertmanager.tag"                     = "v0.24.0"
      # "alertmanager.persistentVolume.enabled" = true
    }

    content {
      name  = set.key
      value = set.value
    }
  }

  values = [
    templatefile("${path.module}/templates/victoria-metrics-alert-values.yaml", local.victoria-metrics-helm-alert-values),
  ]

  depends_on = [kubernetes_config_map.victoria_alerts, kubernetes_config_map.alertmanager]
}


resource "aws_iam_role" "victoria_read_ec2" {
  name        = "victoriametrics-read-ec2-eks-${local.cluster_name}"
  description = "Provides read only access to Amazon EC2 for Victoriametrics ${local.cluster_name}"
  path        = "/"
  tags        = local.tags
  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "sts:AssumeRole"
          ],
          "Principal" : {
            "Service" : [
              "ec2.amazonaws.com"
            ]
          }
        }
      ]
    }
  )
}

resource "aws_iam_role_policy_attachment" "victoria_read_ec2" {
  role       = aws_iam_role.victoria_read_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

resource "aws_iam_user" "victoriametrics" {
  name          = local.namespace_victoria
  path          = "/"
  force_destroy = true
  tags          = local.tags
}

resource "aws_iam_access_key" "victoriametrics" {
  user   = aws_iam_user.victoriametrics.name
  status = "Active"
}

resource "aws_iam_user_policy_attachment" "victoriametrics" {
  user       = aws_iam_user.victoriametrics.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}