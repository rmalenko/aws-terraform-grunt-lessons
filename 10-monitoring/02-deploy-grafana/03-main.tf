# https://artifacthub.io/packages/helm/grafana/grafana

locals {
  grafana_service_account = "grafana"
  # grafana_service_account_annotations = jsonencode(var.service_account_annotations)
  service_type                        = "NodePort"
  service_port                        = 80
  service_target_port                 = 3000
  service_labels                      = { app = "grafana" }
  kubernetes_secret_name              = "grafana-admin-login-and-password"
  grafana_admin_user                  = "admin-user"
  grafana_admin_password              = "admin-password"
  garafana_config_map_dash_name       = "grafana_dashboard"
  garafana_config_map_datasource_name = "grafana_datasource"
  cluster_name                       = data.terraform_remote_state.eks.outputs.cluster_id
  cluster_endpoint                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_certificate_authority_data = data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data
  namespace_victoria                 = data.terraform_remote_state.victoriametrics.outputs.namespace_victoria
  name_persistent_volume_claim       = "victoria-metrics"
  size_of_persistent_volume_claim    = "10Gi"
  eks_iput_target                    = data.terraform_remote_state.efs-nfs.outputs.dns_of_efs_mount_target
  kubernetes_storage_class_name      = data.terraform_remote_state.efs_csi_driver.outputs.kubernetes_storage_class
  domain_name_public                 = data.terraform_remote_state.vpc.outputs.domain_name_public
  domain_name_private                = data.terraform_remote_state.vpc.outputs.domain_name_private
  tolerations_key                    = data.terraform_remote_state.victoriametrics.outputs.tolerations_key
  tolerations_value                  = data.terraform_remote_state.victoriametrics.outputs.tolerations_value

  grafana_val = {
    "tolerations" : [
      {
        "key" : "${local.tolerations_key}",
        "operator" : "Equal",
        "value" : "${local.tolerations_value}",
        "effect" : "NoSchedule"
      }
    ]

    "persistence" : {
      "type" : "pvc",
      "enabled" : true,
      "storageClassName" : "efs-sc",
      "accessModes" : [
        "ReadWriteOnce"
      ],
      "size" : local.size_of_persistent_volume_claim,
      "annotations" : {},
      "finalizers" : [
        "kubernetes.io/pvc-protection"
      ],
      "selectorLabels" : {},
      "subPath" : "",
      "existingClaim" : local.name_persistent_volume_claim
    }

    "grafana.ini" : {
      "paths" : {
        "data" : "/var/lib/grafana/grafana-db",
        "logs" : "/var/log/grafana",
        "plugins" : "/var/lib/grafana/plugins",
        "provisioning" : "/etc/grafana/provisioning"
      },
      "analytics" : {
        "check_for_updates" : true
      },
      "log" : {
        "mode" : "console"
      },
      "grafana_net" : {
        "url" : "https://grafana.net"
      },
      "server" : {
        "root_url" : "http://127.0.0.1:3000/grafana",
        "serve_from_sub_path" : true,
        "enable_gzip" : true
      },
      "database" : {
        "database" : "sqlite3",
        "cache_mode" : "private"
      },
      "users" : {
        "allow_sign_up" : false,
        "allow_org_create" : false,
        "auto_assign_org" : true,
        "auto_assign_org_id" : 1,
        "auto_assign_org_role" : "Viewer",
        "verify_email_enabled" : false,
        "login_hint" : "email or username",
        "password_hint" : "password",
        "default_theme" : "dark"
      },
      "dashboards" : {
        "versions_to_keep" : 20
      },
      "auth.anonymous" : {
        "enabled" : false,
        "org_name" : "Apptopia",
        "org_role" : "Viewer",
        "hide_version" : false
      }
    }

    "plugins" : [
      "grafana-worldmap-panel",
      "grafana-clock-panel",
      "macropower-analytics-panel",
      "farski-blendstat-panel",
      "ryantxu-annolist-panel",
      "yesoreyeram-boomtable-panel",
      "neocat-cal-heatmap-panel",
      "marcusolsson-calendar-panel",
      "petrslavotinek-carpetplot-panel",
      "integrationmatters-comparison-panel",
      "briangann-gauge-panel",
      "briangann-datatable-panel",
      "natel-discrete-panel",
      "marcusolsson-dynamictext-panel",
      "marcusolsson-gantt-panel",
      "citilogics-geoloop-panel",
      "marcusolsson-hexmap-panel",
      "marcusolsson-hourly-heatmap-panel",
      "isaozler-paretochart-panel",
      # "alexanderzobnin-zabbix-app",
      # "redis-app",
      # "redis-datasource",
      # "grafana-redshift-datasource",
      # "grafana-athena-datasource",
      # "grafana-timestream-datasource",
      # "hadesarchitect-cassandra-datasource",
      # "grafana-clickhouse-datasource",
      # "sbueringer-consul-datasource"
    ]

  }

  gateway_grafana = {
    http_gateway = "http-gateway-grafana"
    namespace    = local.namespace_victoria
  }

  grafana_istio_virtual_service = {
    route_to_host = local.grafana_service_account
    name          = local.grafana_service_account
    namespace     = local.namespace_victoria
    hosts         = local.domain_name_public
    gateways      = lookup(local.gateway_grafana, "http_gateway", "http-gateway-grafana")
  }
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

## It doesn't need to create additional volume and persistent_volume_claim. We are using previously created one in 10-VictoriaMetrics
# resource "kubernetes_persistent_volume" "grafana" {
#   metadata {
#     name = local.name_persistent_volume_claim
#     labels = {
#       Name    = "grafana"
#       purpose = "grafana"
#     }
#   }
#   spec {
#     storage_class_name               = local.kubernetes_storage_class_name
#     persistent_volume_reclaim_policy = "Retain"
#     volume_mode                      = "Filesystem"
#     access_modes                     = ["ReadWriteMany"]
#     capacity = {
#       storage = local.size_of_persistent_volume_claim
#     }
#     persistent_volume_source {
#       nfs {
#         path   = "/"
#         server = local.eks_iput_target
#       }
#     }
#   }
# }

# resource "kubernetes_persistent_volume_claim" "grafana" {
#   wait_until_bound = true

#   metadata {
#     name      = local.name_persistent_volume_claim
#     namespace = local.namespace_victoria
#     annotations = {
#       Description = "Volume for Grafana DB"
#     }
#     labels = {
#       Name    = "grafana"
#       purpose = "grafana"
#     }
#   }

#   spec {
#     access_modes       = ["ReadWriteMany"]
#     storage_class_name = local.kubernetes_storage_class_name
#     volume_name        = kubernetes_persistent_volume.grafana.metadata.0.name

#     resources {
#       requests = {
#         storage = local.size_of_persistent_volume_claim
#       }
#       limits = {
#         storage = local.size_of_persistent_volume_claim
#       }
#     }

#     # selector {
#     #   match_labels = {
#     #     k8s-app = "grafana"
#     #     purpose = "grafana"
#     #   }

#     #   match_expressions {
#     #     key      = "k8s-app"
#     #     operator = "In"
#     #     values   = ["grafana"]
#     #   }
#     # }
#   }
#   timeouts {
#     create = "5m"
#   }
# }


resource "helm_release" "grafana" {
  name        = var.release_name
  chart       = var.chart_name
  repository  = var.chart_repository
  version     = var.chart_version
  namespace   = local.namespace_victoria
  max_history = var.max_history

  dynamic "set" {
    for_each = {
      "rbac.create"              = true
      "rbac.pspEnabled"          = true
      "rbac.pspUseAppArmor"      = true
      "rbac.namespaced"          = false
      "serviceAccount.create"    = true
      "serviceAccount.name"      = local.grafana_service_account
      "serviceAccount.autoMount" = true
      "service.enabled"          = true
      "service.type"             = local.service_type
      "service.port"             = local.service_port
      "service.targetPort"       = local.service_target_port
      # "service.labels"           = local.service_labels

      "admin.existingSecret" = local.kubernetes_secret_name
      "admin.userKey"        = local.grafana_admin_user
      "admin.passwordKey"    = local.grafana_admin_password

      "sidecar.dashboards.enabled"                            = true
      "sidecar.dashboards.label"                              = local.garafana_config_map_dash_name
      "sidecar.dashboards.folder"                             = "/tmp/dashboards"
      "sidecar.dashboards.provider.foldersFromFilesStructure" = true

      "sidecar.datasources.enabled" = true
      "sidecar.datasources.label"   = local.garafana_config_map_datasource_name

    }
    content {
      name  = set.key
      value = set.value
    }
  }

  values = [
    yamlencode(local.grafana_val)
  ]

}

resource "random_password" "grafana_admin_password" {
  count   = 2
  length  = 16
  upper   = true
  special = false
}

resource "kubernetes_secret" "grafana_admin_password" {
  type = "Opaque"
  metadata {
    name      = local.kubernetes_secret_name
    namespace = local.namespace_victoria
    labels = {
      "app.kubernetes.io/instance" = "grafana"
      "app.kubernetes.io/name"     = "grafana"
    }
    annotations = {
      "meta.helm.sh/release-name"      = "grafana"
      "meta.helm.sh/release-namespace" = "${local.namespace_victoria}"
    }
  }
  data = {
    "${local.grafana_admin_user}"     = random_password.grafana_admin_password[0].result
    "${local.grafana_admin_password}" = random_password.grafana_admin_password[1].result
  }
}

# Creates Istio gateway for grafana in victoriametrics namespace
data "kubectl_file_documents" "gateway_grafana" {
  content = templatefile("${path.module}/templates/istio-gateway.yml", local.gateway_grafana)
}

resource "kubectl_manifest" "gateway_grafana" {
  for_each  = data.kubectl_file_documents.gateway_grafana.manifests
  yaml_body = each.value
}

# # Creates Istio virtual service for grafana in victoriametrics namespace
data "kubectl_file_documents" "virtual_service_grafana" {
  content = templatefile("${path.module}/templates/grafana_istio_virtual_service.yml", local.grafana_istio_virtual_service)
}

resource "kubectl_manifest" "virtual_service_grafana" {
  for_each  = data.kubectl_file_documents.virtual_service_grafana.manifests
  yaml_body = each.value
}

# https://grafana.com/orgs/istio/dashboards
resource "kubernetes_config_map" "dashboards-istio" {
  metadata {
    name      = "grafana-dashboard-istio"
    namespace = local.namespace_victoria

    labels = {
      "${local.garafana_config_map_dash_name}" = 1
    }

    annotations = {
      k8s-sidecar-target-directory = "/tmp/dashboards/istio"
    }
  }

  data = {
    "istio-control-plane-dashboard.json" = file("${path.module}/dashboards/istio-control-plane-dashboard_rev104.json")
    "istio-workload-dashboard.json"      = file("${path.module}/dashboards/istio-workload-dashboard_rev104.json")
    "istio-service-dashboard.json"       = file("${path.module}/dashboards/istio-service-dashboard_rev104.json")
    "istio-mesh-dashboard.json"          = file("${path.module}/dashboards/istio-mesh-dashboard_rev104.json")
  }
}

resource "kubernetes_config_map" "victoriametrics" {
  metadata {
    name      = "victoria-metrics"
    namespace = local.namespace_victoria

    labels = {
      "${local.garafana_config_map_dash_name}" = 1
    }

    annotations = {
      k8s-sidecar-target-directory = "/tmp/dashboards/victoriametrics"
    }
  }

  data = {
    "VictoriaMetrics-single.json"  = file("${path.module}/dashboards/VictoriaMetrics-single.json")
    "VictoriaMetrics-vmalert.json" = file("${path.module}/dashboards/VictoriaMetrics-vmalert.json")
  }
}

resource "kubernetes_config_map" "dashboards-k8s-01" {
  metadata {
    name      = "k8s-kubernetes-overview-dashboards-k8s-01"
    namespace = local.namespace_victoria
    labels = {
      "${local.garafana_config_map_dash_name}" = 1
    }
    annotations = {
      k8s-sidecar-target-directory = "/tmp/dashboards/k8s"
    }
  }
  data = {
    "kubernetes-sys-API-server.json"   = file("${path.module}/dashboards/kubernetes-sys-API-server.json")
    "kubernetes-views-namespaces.json" = file("${path.module}/dashboards/kubernetes-views-namespaces.json")
    "kubernetes_views_nodes.json"      = file("${path.module}/dashboards/kubernetes_views_nodes.json")
    "k8s-coredns.json"                 = file("${path.module}/dashboards/k8s-coredns.json")
    "k8s-coredns-2.json"               = file("${path.module}/dashboards/k8s-coredns-2.json")
    "k8s-nodes.json"                   = file("${path.module}/dashboards/k8s-nodes.json")
    "node-exporter-full.json"          = file("${path.module}/dashboards/node-exporter-full.json")
    "kube_storageclass_info.json"      = file("${path.module}/dashboards/kube_storageclass_info.json")
    "k8s-kubernetes-overview.json"     = file("${path.module}/dashboards/k8s-kubernetes-overview.json")
    "k8s_views_global.json"            = file("${path.module}/dashboards/k8s_views_global.json")
  }
}

# resource "kubernetes_config_map" "dashboards-k8s-02" {
#   metadata {
#     name      = "k8s-kubernetes-overview-dashboards-k8s-02"
#     namespace = local.namespace_victoria
#     labels = {
#       "${local.garafana_config_map_dash_name}" = 1
#     }
#     annotations = {
#       k8s-sidecar-target-directory = "/tmp/dashboards/k8s-02"
#     }
#   }
#   data = {
#     "k8s-resources-workloads-namespace.json" = file("${path.module}/dashboards/k8s-resources-workloads-namespace.json")
#   }
# }

resource "kubernetes_config_map" "grafana-grafana-datasource" {
  metadata {
    name      = "grafana-datasources"
    namespace = local.namespace_victoria

    labels = {
      "${local.garafana_config_map_datasource_name}" = 1
    }
  }

  data = {
    "datasources.yaml" = file("${path.module}/datasources/datasources.yaml")
  }
}

resource "local_sensitive_file" "user_credentials" {
  content = templatefile("${path.module}/templates/user-credentials.tpl", {
    user_name = coalesce(random_password.grafana_admin_password[0].result, "The data wasn't provided")
    password  = coalesce(random_password.grafana_admin_password[1].result, "The data wasn't provided")
  })
  filename = "${path.module}/user_credentials_grafana.txt"
}
