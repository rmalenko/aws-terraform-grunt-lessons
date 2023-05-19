## To-d0: automate adding user or SSO integration.
## https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/
## =================================================================================

locals {
  namespace                          = "argo-cd"
  subdomain                          = "argo-cd"
  namespace_alb                      = data.terraform_remote_state.alb-controller.outputs.alb-controller_namespace
  cluster_certificate_authority_data = data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data
  cluster_name                       = data.terraform_remote_state.eks.outputs.cluster_id
  cluster_endpoint                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_oidc_issuer_url            = data.terraform_remote_state.eks.outputs.cluster_oidc_issuer_url
  oidc_arn                           = data.terraform_remote_state.eks.outputs.oidc_provider_arn
  aws_template_name_karpenter        = data.terraform_remote_state.karpenter_and_launch_template.outputs.aws_template_name_karpenter
  eks_iput_target                    = data.terraform_remote_state.efs-nfs.outputs.dns_of_efs_mount_target
  kubernetes_storage_class_name      = data.terraform_remote_state.efs_csi_driver.outputs.kubernetes_storage_class
  argo-cd-conf-map                   = "argo-cd"
  tolerations_key                    = "purpose"
  tolerations_value                  = "ci-cd"
  helm_wait_tiimeout                 = 300
  argo-cd_chart_version              = "4.6.5"
  size_of_persistent_volume_claim    = "250Gi"
  name_persistent_volume_claim       = "argo-cd-nfs"

  aws_lbc_lb_https_grpc = {
    namespace               = local.namespace
    namespace_alb           = local.namespace_alb
    name_http_ingress       = "argo-cd-server-test"
    name_grpc_service       = "argo-cd-grpc-test"
    waf                     = data.terraform_remote_state.waf.outputs.aws_wafv2_web_acl_arn
    domain_certificate      = data.terraform_remote_state.domain.outputs.acm_certificate_arn
    domain_name_public      = "${local.subdomain}.${data.terraform_remote_state.vpc.outputs.domain_name_public}"
    domain_name_public_grpc = "argo-cd-grpc.${data.terraform_remote_state.vpc.outputs.domain_name_public}"
    tags_env                = var.env
    tolerations_key         = local.tolerations_key
    tolerations_value       = local.tolerations_value
  }

  argocd_ingress_annotations = {
    "kubernetes.io/ingress.class"                    = "nginx"
    "nginx.ingress.kubernetes.io/force-ssl-redirect" = "true"
    "nginx.ingress.kubernetes.io/ssl-passthrough"    = "true"
  }

  config = {
    "accounts.image-updater" = "apiKey"
  }

  argocd_repositories = {
    # [
    "private-repo" = {
      url      = "https://repo.git"
      username = "argocd"
      password = "access_token"
    },
    "git-repo" = {
      url      = "https://repo.git"
      password = "argocd_access_token" # when using access token, you pass a random username
      username = "admin"
    },
    "private-helm-chart" = {
      url      = "https://charts.jetstack.io"
      type     = "helm"
      username = "foo"
      password = "bar"
    },
    # ]
  }

  # Remove map keys from all_repositories with no value. That means they were not specified
  clean_repositories = {
    for name, repo in local.argocd_repositories : "${name}" => {
      for k, v in repo : k => v if v != null
    }
  }

  # https://github.com/argoproj/argo-cd/blob/master/docs/operator-manual/rbac.md
  rbac_config = {
    "policy.default" = "role:readonly"
    "policy.csv"     = <<POLICY
  p, role:image-updater, applications, get, */*, allow
  p, role:image-updater, applications, update, */*, allow
  p, role:org-admin, applications, *, */*, allow
  p, role:org-admin, clusters, get, *, allow
  p, role:org-admin, repositories, get, *, allow
  p, role:org-admin, repositories, create, *, allow
  p, role:org-admin, repositories, update, *, allow
  p, role:org-admin, repositories, delete, *, allow
  p, role:org-admin, logs, get, *, allow
  p, role:org-admin, exec, create, */*, allow
  g, image-updater, role:image-updater
  g, org-user-admin, role:org-admin
POLICY
  }

  # If no_auth_config has been specified, set all configs as null
  argocd_values = merge({
    global = {
      image = {
        tag = var.image_tag
      }
    }

    server = {
      config     = local.config
      rbacConfig = local.rbac_config
      # Run insecure mode if specified, to prevent argocd from using it's own certificate
      extraArgs = var.server_insecure ? ["--insecure"] : null
      # Ingress Values
      # ingress = {
      #   enabled     = var.ingress_host != null ? true : false
      #   https       = true
      #   annotations = var.ingress_annotations
      #   hosts       = [var.ingress_host]
      #   tls = var.server_insecure ? [{
      #     secretName = var.ingress_tls_secret
      #     hosts      = [var.ingress_host]
      #   }] : null
      # }
    }
    configs = {
      # Configmaps require strings, yamlencode the map
      repositories = local.clean_repositories
    }

    repoServer = {
      "volumes" : [
        {
          "name" = "${local.name_persistent_volume_claim}"
          "persistentVolumeClaim" = {
            "claimName" = "${local.name_persistent_volume_claim}"
          }
        }
      ],
      "containers" : [
        {
          "name" = "repo-server",
          "volumeMounts" = [
            {
              "name"      = "${local.name_persistent_volume_claim}"
              "mountPath" = "/tmp"
            }
          ]
        }
      ]
    }

  })
}


resource "null_resource" "helm_repo" {
  provisioner "local-exec" {
    command = <<EOF
    set -xe
    cd ${path.root}
    rm -rf ./karpenter-${local.argo-cd_chart_version} || true
    wget https://github.com/argoproj/argo-helm/releases/download/argo-cd-${local.argo-cd_chart_version}/argo-cd-${local.argo-cd_chart_version}.tgz && tar -xvzf argo-cd-${local.argo-cd_chart_version}.tgz
    EOF
  }
  triggers = {
    build_number = local.argo-cd_chart_version
  }
}

resource "kubernetes_namespace" "argo-cd" {
  metadata {
    name = local.namespace
    annotations = {
      name            = local.namespace
      istio-injection = "enabled"
    }
    labels = {
      Name                                      = local.namespace
      purpose                                   = local.namespace
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

# https://artifacthub.io/packages/helm/argo/argo-cd
resource "helm_release" "argo-cd" {
  name             = var.argo-cd_release_name
  chart            = var.argo-cd_chart
  repository       = var.argo-cd_chart_repository_url
  version          = var.argo-cd_chart_version
  namespace        = local.namespace
  max_history      = var.max_history
  create_namespace = false
  timeout          = local.helm_wait_tiimeout

  dynamic "set" {
    for_each = {

      "controller.tolerations[0].key"      = local.tolerations_key
      "controller.tolerations[0].value"    = local.tolerations_value
      "controller.tolerations[0].operator" = "Equal"
      "controller.tolerations[0].effect"   = "NoSchedule"

      "dex.tolerations[0].key"      = local.tolerations_key
      "dex.tolerations[0].value"    = local.tolerations_value
      "dex.tolerations[0].operator" = "Equal"
      "dex.tolerations[0].effect"   = "NoSchedule"

      "redis.tolerations[0].key"      = local.tolerations_key
      "redis.tolerations[0].value"    = local.tolerations_value
      "redis.tolerations[0].operator" = "Equal"
      "redis.tolerations[0].effect"   = "NoSchedule"

      "server.service.type"            = "NodePort"
      "server.tolerations[0].key"      = local.tolerations_key
      "server.tolerations[0].value"    = local.tolerations_value
      "server.tolerations[0].operator" = "Equal"
      "server.tolerations[0].effect"   = "NoSchedule"

      "repoServer.tolerations[0].key"      = local.tolerations_key
      "repoServer.tolerations[0].value"    = local.tolerations_value
      "repoServer.tolerations[0].operator" = "Equal"
      "repoServer.tolerations[0].effect"   = "NoSchedule"

      # "repoServer.volumeMounts" = yamlencode({ name = "${local.name_persistent_volume_claim}", mountPath = "/tmp" })
      # "repoServer.volumeMounts" = { name = "${local.name_persistent_volume_claim}", mountPath = "/tmp" }


      "applicationSet.tolerations[0].key"      = local.tolerations_key
      "applicationSet.tolerations[0].value"    = local.tolerations_value
      "applicationSet.tolerations[0].operator" = "Equal"
      "applicationSet.tolerations[0].effect"   = "NoSchedule"

      "notifications.tolerations[0].key"                 = local.tolerations_key
      "notifications.tolerations[0].value"               = local.tolerations_value
      "notifications.tolerations[0].operator"            = "Equal"
      "notifications.tolerations[0].effect"              = "NoSchedule"
      "notifications.bots.slack.tolerations[0].key"      = local.tolerations_key
      "notifications.bots.slack.tolerations[0].value"    = local.tolerations_value
      "notifications.bots.slack.tolerations[0].operator" = "Equal"
      "notifications.bots.slack.tolerations[0].effect"   = "NoSchedule"


      # "server.ingress.enabled"                                                           = false
      # "server.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/conditions\\.argogrpc" = "[{\"field\":\"http-header\"\\,\"httpHeaderConfig\":{\"httpHeaderName\": \"Content-Type\"\\, \"values\":[\"application/grpc\"]}}]"

      "server.autoscaling.enabled"                           = true
      "server.autoscaling.targetCPUUtilizationPercentage"    = 75
      "server.autoscaling.targetMemoryUtilizationPercentage" = 75


    }
    content {
      name  = set.key
      value = set.value
    }

  }

  # values = concat(
  #   [yamlencode(local.argocd_values)],
  #   # [yamlencode(local.argocd_values), yamlencode(local.argocd_values)],
  #   [for x in var.values_files : file(x)]
  # )

  values = [yamlencode(local.argocd_values)]
}


resource "kubectl_manifest" "alb_argo_https" {
  yaml_body  = templatefile("${path.module}/templates/alb-internet-facing-alb-argo-https.yml", local.aws_lbc_lb_https_grpc)
  depends_on = [helm_release.argo-cd]
}

resource "kubectl_manifest" "alb_argo_grpc" {
  yaml_body  = templatefile("${path.module}/templates/alb-internet-facing-alb-argo-grpc.yml", local.aws_lbc_lb_https_grpc)
  depends_on = [kubectl_manifest.alb_argo_https]
}

resource "null_resource" "previous" {
  depends_on = [kubectl_manifest.alb_argo_grpc]
}

resource "time_sleep" "wait_90_seconds" {
  depends_on      = [null_resource.previous]
  create_duration = "120s"
}

data "aws_lb" "arn_dns" {
  name       = lookup(local.aws_lbc_lb_https_grpc, "name_http_ingress", "argo-cd-server")
  depends_on = [time_sleep.wait_90_seconds]
}

resource "aws_route53_record" "subdomain" {
  for_each = toset(["${local.subdomain}.${data.terraform_remote_state.vpc.outputs.domain_name_public}"])
  zone_id  = data.terraform_remote_state.domain.outputs.route53_zone_zone_id_public
  name     = each.key
  type     = "A"

  alias {
    name                   = data.aws_lb.arn_dns.dns_name
    zone_id                = data.aws_lb.arn_dns.zone_id
    evaluate_target_health = true
  }

  depends_on = [
    data.aws_lb.arn_dns
  ]
}

resource "kubectl_manifest" "user_add" {
  yaml_body = <<-YAML
    apiVersion: v1
    kind: ConfigMap
    metadata:
        name: argocd-cm
        namespace: "${local.namespace}"
        annotations:
          meta.helm.sh/release-name: argo-cd
          meta.helm.sh/release-namespace: "${local.namespace}"
        labels:
          app.kubernetes.io/managed-by: Helm
          app.kubernetes.io/name: argocd-cm
          app.kubernetes.io/part-of: argocd
    data:
        statusbadge.enabled: "true"
        users.anonymous.enabled: "false"
        users.session.duration: "24h"
        configManagementPlugins: |
          - name: kasane
            init:
              command: [kasane, update]
            generate:
              command: [kasane, show]
        admin.enabled: "true"
        # add an additional local user with apiKey and login capabilities
        #   apiKey - allows generating API keys
        #   login - allows to login using UI
        accounts.alice: apiKey, login
        # disables user. User is enabled by default
        accounts.alice.enabled: "true"
  YAML
}


resource "kubernetes_persistent_volume" "argo-cd-volume" {
  metadata {
    name = local.name_persistent_volume_claim
    labels = {
      Name    = "argo-cd-volume"
      purpose = "argo-cd-volume"
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

resource "kubernetes_persistent_volume_claim" "argo-cd-volume" {
  wait_until_bound = true

  metadata {
    name      = local.name_persistent_volume_claim
    namespace = local.namespace
    annotations = {
      Description = "Volume for argo-cd-volume DB"
    }
    labels = {
      Name                                      = "argo-cd-volume"
      purpose                                   = "argo-cd-volume"
      "elbv2.k8s.aws/pod-readiness-gate-inject" = "enabled"
    }
  }

  spec {
    access_modes       = ["ReadWriteMany"]
    storage_class_name = local.kubernetes_storage_class_name
    volume_name        = kubernetes_persistent_volume.argo-cd-volume.metadata.0.name

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