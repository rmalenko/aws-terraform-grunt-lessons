// https://kubernetes-sigs.github.io/aws-load-balancer-controller
// https://rtfm.co.ua/istio-integraciya-inrgress-gateway-s-aws-application-loadbalancer/

locals {
  cluster_name                            = data.terraform_remote_state.eks.outputs.cluster_id
  vpc_id                                  = data.terraform_remote_state.vpc.outputs.vpc_id
  domain_name_public                      = data.terraform_remote_state.vpc.outputs.domain_name_public
  domain_name_private                     = data.terraform_remote_state.vpc.outputs.domain_name_private
  cluster_oidc_issuer_url                 = data.terraform_remote_state.eks.outputs.cluster_oidc_issuer_url
  aws_template_name_karpenter             = data.terraform_remote_state.karpenter_and_launch_template.outputs.aws_template_name_karpenter
  aws_iam_instance_profile_name_karpenter = data.terraform_remote_state.karpenter_and_launch_template.outputs.aws_iam_instance_profile_name_karpenter
  namespace                               = "istio-system"
  serviceaccount_alb                      = lookup(local.aws_lbc, "serviceaccount", "aws-load-balancer-controller")
  istio_ingressgateway_service_account    = "istio-ingressgateway-service-account"
  oidc_fully_qualified_subjects           = format("system:serviceaccount:%s:%s", local.namespace, local.serviceaccount_alb)
  oidc_arn                                = data.terraform_remote_state.eks.outputs.oidc_provider_arn
  oidc_url                                = trimprefix("${data.terraform_remote_state.eks.outputs.cluster_oidc_issuer_url}", "https://")
  oidc_url_full                           = data.terraform_remote_state.eks.outputs.cluster_oidc_issuer_url
  cluster_endpoint                        = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_certificate_authority_data      = data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data
  helm_wait_tiimeout                      = 600
  helm_wait_if                            = true # or false
  tolerations_key                         = "k8s-app"
  tolerations_value                       = "istio_aws_alb"
  tolerations_operator                    = "Equal"
  tolerations_effect                      = "NoSchedule"
  tag_istio_images                        = "1.13.2"

  istio_ingress_status_port_nodeport = 30213

  version_git_release = var.istio_git_release_version

  eks-owned-tag = {
    format("kubernetes.io/cluster/%s", local.cluster_name) = "owned"
  }

  default-tags = merge(
    { "terraform.io" = "managed" },
    { "Name" = local.namespace },
    local.eks-owned-tag
  )
  tags = { "env" = "test" }

  istio_helm = {
    repository                 = "https://aws.github.io/eks-charts"
    name                       = "aws-load-balancer-controller"
    helm_chart_name            = "istio-operator"
    istio_helm_release_version = var.helm_chart_version_istio
    namespace                  = local.namespace
    serviceaccount             = "aws-load-balancer-controller"
    cleanup_on_fail            = true

  }

  aws_lbc = {
    name               = "aws-load-balancer-controller"
    chart              = "aws-load-balancer-controller"
    version_helm       = "1.4.0"
    alb_tag            = "v2.4.0"
    ingressClass       = "alb" # The ingress class this controller will satisfy. If not specified, controller will match all ingresses without ingress class annotation and ingresses of type alb
    repository         = "https://aws.github.io/eks-charts"
    cleanup_on_fail    = true
    serviceaccount_alb = "aws-load-balancer-controller"
    nodeSelector_key   = local.tolerations_key
    nodeSelector_value = local.tolerations_value
  }

  aws_lbc_lb_front = {
    name                             = "grafana-victoriametrics"
    namespace                        = local.namespace
    waf                              = data.terraform_remote_state.waf.outputs.aws_wafv2_web_acl_arn
    domain-certificate               = data.terraform_remote_state.domain.outputs.acm_certificate_arn
    domain_name_public               = data.terraform_remote_state.vpc.outputs.domain_name_public
    tags                             = var.env
    istio_system_toleration_key_name = local.tolerations_key
    # istio_system_toleration_key_purpose = data.terraform_remote_state.eks.outputs.istio_system_toleration_key_purpose
    istio-system_toleration_value = local.tolerations_value

  }

  aws_lbc_tolerations = {
    "tolerations" : [
      {
        "key" : "${local.tolerations_key}",
        "operator" : "Equal",
        "value" : "${local.tolerations_value}",
        "effect" : "NoSchedule"
      }
    ]
  }

  istio_default_toleration = {
    "tolerations" : [
      {
        "key" : "${local.tolerations_key}",
        "operator" : "Equal",
        "value" : "${local.tolerations_value}",
        "effect" : "NoSchedule"
      }
    ]

    # "ports" : [
    #   {
    #     "port" : 15021,
    #     "targetPort" : 15021,
    #     "name" : "status-port",
    #     "protocol" : "TCP",
    #     "nodePort" : 30213
    #   },
    #   {
    #     "port" : 80,
    #     "targetPort" : 8080,
    #     "name" : "http2",
    #     "protocol" : "TCP"
    #   },
    #   {
    #     "port" : 443,
    #     "targetPort" : 8443,
    #     "name" : "https",
    #     "protocol" : "TCP"
    #   }
    # ]

  }

  istio_discovery = {
    tag_istio_images      = local.tag_istio_images
    namespace             = local.namespace
    autoscaleMin          = 1
    autoscaleMax          = 5
    replicaCount          = 1
    rollingMaxSurge       = "100%"
    rollingMaxUnavailable = "25%"
    requests_cpu          = "500m"
    requests_memory       = "2048Mi"
    nodeSelector_key      = local.tolerations_key
    nodeSelector_value    = local.tolerations_value

    "pilot.nodeSelector" : {
      "${local.tolerations_key}" : "${local.tolerations_value}"
    }

    "tolerations" : [
      {
        "key" : "${local.tolerations_key}",
        "operator" : "Equal",
        "value" : "${local.tolerations_value}",
        "effect" : "NoSchedule"
      }
    ]
  }

  istio_ingress = {
    tag_istio_images     = local.tag_istio_images
    autoscaleMin         = 1
    autoscaleMax         = 5
    requests_cpu         = "100m"
    requests_memory      = "128Mi"
    limit_cpu            = "2000m"
    limit_memory         = "1024Mi"
    loadbalancer_type    = "NodePort" # to create a targe group needs to be: NodePort. Change to NodePort, ClusterIP or LoadBalancer if need be
    status_port_nodeport = "30213"
    nodeSelector_key     = local.tolerations_key
    nodeSelector_value   = local.tolerations_value

    "tolerations" : [
      {
        "key" : "${local.tolerations_key}",
        "operator" : "Equal",
        "value" : "${local.tolerations_value}",
        "effect" : "NoSchedule"
      }
    ]

    # "ports" : [
    #   {
    #     "name" : "status-port",
    #     "protocol" : "TCP",
    #     "port" : 15021,
    #     "targetPort" : 15021,
    #     "nodePort" : 30213
    #   },
    #   {
    #     "name" : "http2",
    #     "protocol" : "TCP",
    #     "port" : 80,
    #     "targetPort" : 80,
    #     # "nodePort": 30968
    #   },
    #   {
    #     "name" : "https",
    #     "protocol" : "TCP",
    #     "port" : 443,
    #     "targetPort" : 443,
    #     # "nodePort": 32759
    #   }
    # ]
  }

  istio_egress = {
    tag_istio_images   = local.tag_istio_images
    autoscaleMin       = 1
    autoscaleMax       = 5
    requests_cpu       = "100m"
    requests_memory    = "128Mi"
    limit_cpu          = "2000m"
    limit_memory       = "1024Mi"
    nodeSelector_key   = local.tolerations_key
    nodeSelector_value = local.tolerations_value
  }

  istio_operator = {
    tag_istio_images   = local.tag_istio_images
    requests_cpu       = "50m"
    requests_memory    = "128Mi"
    limit_cpu          = "200m"
    limit_memory       = "256Mi"
    nodeSelector_key   = local.tolerations_key
    nodeSelector_value = local.tolerations_value
  }

}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/kubeconfig-dev"
  }
}

# Get auth token
data "aws_eks_cluster_auth" "default" {
  name = local.cluster_name
}

provider "kubernetes" {
  config_path            = "~/.kube/kubeconfig-dev"
  host                   = local.cluster_endpoint
  cluster_ca_certificate = base64decode(local.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.default.token
  # experiments {
  #   manifest_resource = true
  # }
}

provider "kubectl" {
  host                   = local.cluster_endpoint
  cluster_ca_certificate = base64decode(local.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.default.token
  load_config_file       = false
}

resource "kubernetes_namespace" "istio_system" {
  metadata {
    annotations = {
      istio-injection = "enabled"
    }
    labels = {
      label                                     = local.namespace
      istio-injection                           = "enabled"
      "elbv2.k8s.aws/pod-readiness-gate-inject" = "enabled"
    }
    name = local.namespace
  }
}

# resource "null_resource" "helm_repo" {
#   provisioner "local-exec" {
#     command = <<EOF
#     set -xe
#     cd ${path.root}
#     rm -rf ./istio-${var.istio_git_release_version} || true
#     curl -sL https://git.io/getLatestIstio | ISTIO_VERSION=${var.istio_git_release_version} TARGET_ARCH=x86_64 sh -
#     rm -rf ./istio || true
#     mv ./istio-${var.istio_git_release_version} istio

#     # values.yaml will create later from template
#     # rm ./istio/manifests/charts/gateways/istio-ingress/values.yaml  || true
#     # sed -e 's|extensions/v1beta1|policy/v1beta1|g' istio/samples/security/psp/all-pods-psp.yaml > istio/install/kubernetes/helm/istio-init/templates/all-pods-psp.yaml
#     # sed -e 's|extensions/v1beta1|policy/v1beta1|g' istio/samples/security/psp/citadel-agent-psp.yaml > istio/install/kubernetes/helm/istio-init/templates/citadel-agent-psp.yaml
#     EOF
#   }

#   triggers = {
#     # build_number = formatdate("YYYYMMDD", timestamp())
#     # build_number = formatdate("YYYY-MM-DD", timestamp())
#     # build_number = timestamp()
#     build_number = var.istio_git_release_version
#   }
# }

# resource "null_resource" "helm_repo" {
#   provisioner "local-exec" {
#     command = <<EOF
#     set -xe
#     cd ${path.root}
#     sudo rm -rf  ./istio-${var.istio_git_release_version} || true
#     git clone https://github.com/istio/istio.git
#     # wget --recursive --continue https://github.com/istio/istio/tree/master/manifests/charts
#     EOF
#   }

#   triggers = {
#     # build_number = formatdate("YYYYMMDD", timestamp())
#     # build_number = formatdate("YYYY-MM-DD", timestamp())
#     # build_number = timestamp()
#     build_number = var.istio_git_release_version
#   }
# }

resource "helm_release" "istio_base" {
  # repository       = var.helm_repository
  # chart            = "base"
  chart = "${path.module}/istio/manifests/charts/base"
  name  = "istio-base"
  # version          = var.helm_chart_version_istio
  namespace        = local.namespace
  create_namespace = false
  wait             = local.helm_wait_if
  timeout          = local.helm_wait_tiimeout
  cleanup_on_fail  = true
  force_update     = true
  recreate_pods    = true
  max_history      = "10"

  dynamic "set" {
    for_each = {
      "global.istioNamespace" = "${local.namespace}"
    }
    content {
      name  = set.key
      value = set.value
    }
  }

  values = [
    yamlencode(local.istio_default_toleration)
  ]

  depends_on = [kubernetes_namespace.istio_system, kubectl_manifest.karpenter_provisioner]
}

# ## It will create deployment.yaml with added tolerations and replace original file.
# resource "local_file" "istio_control_discovery_deployment" {
#   content         = file("${path.module}/templates/istio_discovery_deployment.yaml")
#   filename        = "${path.module}/istio/manifests/charts/istio-control/istio-discovery/templates/deployment.yaml"
#   file_permission = "0644"
#   depends_on      = [null_resource.helm_repo]
# }

resource "helm_release" "istio-discovery" {
  # repository = var.helm_repository
  # repository = "https://github.com/istio/istio/tree/master/manifests/charts/istio-control"
  # chart      = "istio-discovery"
  # version          = var.helm_chart_version_istio
  chart            = "${path.module}/istio/manifests/charts/istio-control/istio-discovery"
  name             = "istio-discovery"
  namespace        = local.namespace
  create_namespace = false
  wait             = local.helm_wait_if
  timeout          = local.helm_wait_tiimeout
  cleanup_on_fail  = true
  force_update     = true
  recreate_pods    = true
  max_history      = "10"
  depends_on       = [helm_release.istio_base]
  # depends_on = [local_file.istio_control_discovery_deployment]

  dynamic "set" {
    for_each = {
      "global.istioNamespace"         = "${local.namespace}"
      "pilot.tolerations[0].key"      = "${local.tolerations_key}"
      "pilot.tolerations[0].value"    = "${local.tolerations_value}"
      "pilot.tolerations[0].operator" = "Equal"
      "pilot.tolerations[0].effect"   = "NoSchedule"
    }
    content {
      name  = set.key
      value = set.value
    }
  }

  # values = [
  #   yamlencode(local.istio_discovery)
  # ]
  # # values = [  
  # #   templatefile("${path.module}/istio/manifests/charts/istio-control/istio-discovery/values.yaml", local.istio_discovery),
  # # ]
}

resource "helm_release" "istio_ingress" {
  name            = "istio-ingress-gateway"
  chart           = "${path.module}/istio/manifests/charts/gateways/istio-ingress"
  wait            = local.helm_wait_if
  timeout         = local.helm_wait_tiimeout
  cleanup_on_fail = true
  force_update    = true
  recreate_pods   = true
  namespace       = local.namespace
  max_history     = 10
  depends_on      = [helm_release.istio-discovery]
  # depends_on = [null_resource.helm_repo, helm_release.istio-discovery]

  dynamic "set" {
    for_each = {
      "global.istioNamespace" = "${local.namespace}"
      "service.type"          = "NodePort" # to create a targe group needs to be: NodePort. Change to NodePort, ClusterIP or LoadBalancer if need be
      "global.sds.enabled"    = true

      # "gateway.serviceAnnotations.alb\\.ingress\\.kubernetes\\.io/healthcheck-path"     = "/healthz/ready"
      # "gateway.serviceAnnotations.alb\\.ingress\\.kubernetes\\.io/healthcheck-protocol" = "HTTP"
      # "service.annotations.alb\\.ingress\\.kubernetes\\.io/healthcheck-path"     = "/healthz/ready"
      # "service.annotations.alb\\.ingress\\.kubernetes\\.io/healthcheck-protocol" = "HTTP"
      # "gateways.istio-ingressgateway.tolerations[0].key"      = "${local.tolerations_key}"
      # "gateways.istio-ingressgateway.tolerations[0].value"    = "${local.tolerations_value}"
      # "gateways.istio-ingressgateway.tolerations[0].operator" = "Equal"
      # "gateways.istio-ingressgateway.tolerations[0].effect"   = "NoSchedule"

    }

    content {
      name  = set.key
      value = set.value
    }
  }

  values = [
    templatefile("${path.module}/templates/istio-ingress_values.yaml", local.istio_ingress),
  ]
}

resource "helm_release" "istio_egress" {
  # repository       = var.helm_repository
  # chart            = "gateway"
  # version          = var.helm_chart_version_istio
  chart            = "${path.module}/istio/manifests/charts/gateways/istio-egress"
  name             = "istio-egress"
  namespace        = local.namespace
  create_namespace = false
  wait             = local.helm_wait_if
  timeout          = local.helm_wait_tiimeout
  cleanup_on_fail  = true
  force_update     = true
  recreate_pods    = true
  max_history      = "10"
  depends_on       = [helm_release.istio_ingress]

  dynamic "set" {
    for_each = {
      "global.defaultTolerations[0].key"      = "${local.tolerations_key}"
      "global.defaultTolerations[0].value"    = "${local.tolerations_value}"
      "global.defaultTolerations[0].operator" = "Equal"
      "global.defaultTolerations[0].effect"   = "NoSchedule"
    }

    content {
      name  = set.key
      value = set.value
    }
  }

  # values = [
  #   yamlencode(local.istio_default_toleration)
  # ]
}

resource "helm_release" "istio_operator" {
  chart = "${path.module}/istio/manifests/charts/istio-operator"
  name  = "istio-operator"
  # version         = var.helm_chart_version_istio
  namespace       = local.namespace
  wait            = local.helm_wait_if
  timeout         = local.helm_wait_tiimeout
  cleanup_on_fail = true
  force_update    = true
  recreate_pods   = true
  max_history     = "10"
  depends_on      = [helm_release.istio_egress]
  # depends_on      = [null_resource.helm_repo]

  dynamic "set" {
    for_each = {
      # "spec.meshConfig.outboundTrafficPolicy.mode" = "ALLOW_ANY"
    }

    content {
      name  = set.key
      value = set.value
    }
  }

  values = [
    yamlencode(local.istio_default_toleration)
  ]
}

resource "kubectl_manifest" "alb" {
  yaml_body  = templatefile("${path.module}/templates/alb-internet-facing.yml", local.aws_lbc_lb_front)
  depends_on = [helm_release.aws-lbc]
}

resource "null_resource" "previous" {
  depends_on = [kubectl_manifest.alb]
}

resource "time_sleep" "wait_90_seconds" {
  depends_on      = [null_resource.previous]
  create_duration = "300s"
}

data "aws_lb" "arn_dns" {
  name = lookup(local.aws_lbc_lb_front, "name", "grafana-victoriametrics")
  depends_on = [
    time_sleep.wait_90_seconds,
  ]
}

resource "aws_route53_record" "www" {
  for_each = toset(["www.${local.domain_name_public}", local.domain_name_public])
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
