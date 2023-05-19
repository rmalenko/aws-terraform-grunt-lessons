// https://kubernetes-sigs.github.io/aws-load-balancer-controller
// https://rtfm.co.ua/istio-integraciya-inrgress-gateway-s-aws-application-loadbalancer/

locals {
  cluster_name                       = data.terraform_remote_state.eks.outputs.cluster_id
  vpc_id                             = data.terraform_remote_state.vpc.outputs.vpc_id
  domain_name_public                 = data.terraform_remote_state.vpc.outputs.domain_name_public
  domain_name_private                = data.terraform_remote_state.vpc.outputs.domain_name_private
  cluster_oidc_issuer_url            = data.terraform_remote_state.eks.outputs.cluster_oidc_issuer_url
  namespace                          = "alb-controller"
  serviceaccount_alb                 = lookup(local.aws_lbc, "serviceaccount", "aws-load-balancer-controller")
  cluster_endpoint                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_certificate_authority_data = data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data
  helm_wait_tiimeout                 = 600
  helm_wait_if                       = true # or false
  tolerations_key                    = data.terraform_remote_state.eks.outputs.taints_key_criticaladdonsonly
  tolerations_value                  = data.terraform_remote_state.eks.outputs.taints_value_criticaladdonsonly
  tolerations_operator               = "Equal"
  tolerations_effect                 = "NoSchedule"
  version_alb_asg = "1.4.2"

  eks-owned-tag = {
    format("kubernetes.io/cluster/%s", local.cluster_name) = "owned"
  }

  default-tags = merge(
    { "terraform.io" = "managed" },
    { "Name" = local.namespace },
    local.eks-owned-tag
  )
  tags = { "env" = "test" }

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
}

resource "null_resource" "helm_repo" {
  provisioner "local-exec" {
    command = <<EOF
    set -xe
    cd ${path.root}
    rm -rf ./karpenter-${local.version_alb_asg} || true
    wget https://aws.github.io/eks-charts/aws-load-balancer-controller-${local.version_alb_asg}.tgz && tar -xvzf aws-load-balancer-controller-${local.version_alb_asg}.tgz
    EOF
  }
  triggers = {
    build_number = local.version_alb_asg
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
}

provider "kubectl" {
  host                   = local.cluster_endpoint
  cluster_ca_certificate = base64decode(local.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.default.token
  load_config_file       = false
}

resource "kubernetes_namespace" "awsloadbalancer" {
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

resource "aws_iam_policy" "awsloadbalancer" {
  name        = "AWSLoadBalancerControllerIAMPolicy"
  path        = "/"
  description = "Allow aws-load-balancer-controller to manage AWS resources"
  policy = templatefile("${path.module}/policy.json.tpl",
    {
      REGION  = var.aws_region
      ACCOUNT = var.account_id
      VPC-ID  = local.vpc_id
    }
  )
  tags = {
    Name = "AWSLoadBalancerControllerIAMPolicy"
    App  = "kubernetes"
  }
}

module "iam_assumable_role_albc" {
  source           = "../../modules/terraform-aws-iam/modules/iam-assumable-role-with-oidc"
  create_role      = true
  role_name        = "alb-controller-manage"
  provider_url     = replace(local.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns = [aws_iam_policy.awsloadbalancer.arn]
  oidc_fully_qualified_subjects = [
    "system:serviceaccount:${local.namespace}:${local.serviceaccount_alb}"
  ]
  tags = {
    Name = "alb-controller-manage"
    Type = "app_alb"
  }
}

# https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/deploy/configurations/
resource "helm_release" "aws-lbc" {
  name  = lookup(local.aws_lbc, "name", "aws-load-balancer-controller")
  chart = lookup(local.aws_lbc, "chart", "aws-load-balancer-controller")
  # version         = lookup(local.aws_lbc, "version_helm", null)
  repository      = lookup(local.aws_lbc, "repository", "https://aws.github.io/eks-charts")
  namespace       = local.namespace
  cleanup_on_fail = lookup(local.aws_lbc, "cleanup_on_fail", true)
  timeout         = local.helm_wait_tiimeout
  wait            = local.helm_wait_if

  dynamic "set" {
    for_each = {
      "clusterName"                                               = local.cluster_name
      "serviceAccount.name"                                       = lookup(local.aws_lbc, "serviceaccount", "aws-load-balancer-controller")
      "serviceAccount.create"                                     = true
      "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn" = module.iam_assumable_role_albc.iam_role_arn
      "ingress-class"                                             = lookup(local.aws_lbc, "ingressClass", "alb")
      "vpcId"                                                     = local.vpc_id // needs to launch on Fargate
      "aws-vpc-id"                                                = local.vpc_id
      "enableWafv2"                                               = true
      "replicaCount"                                              = 1
      "logLevel"                                                  = "debug"
      # "watchNamespace"                                            = local.namespace // Ingress events outside of the namespace specified are not be seen by the controller.
      # "region"                                                    = var.aws_region // needs to launch on Fargate
      # "aws-region"                                                = var.aws_region // needs to launch on Fargate
    }
    content {
      name  = set.key
      value = set.value
    }
  }
  values = [
    yamlencode(local.aws_lbc_tolerations)
  ]

  depends_on = [kubernetes_namespace.awsloadbalancer]
}

# ## This part will be created in 09-Istio
# ## ----------------------------------------
# resource "kubectl_manifest" "alb" {
#   yaml_body  = templatefile("${path.module}/templates/alb-internet-facing.yml", local.aws_lbc_lb_front)
#   depends_on = [helm_release.aws-lbc]
# }

# resource "null_resource" "previous" {
#   depends_on = [kubectl_manifest.alb]
# }

# resource "time_sleep" "wait_90_seconds" {
#   depends_on      = [null_resource.previous]
#   create_duration = "300s"
# }

# data "aws_lb" "arn_dns" {
#   name = lookup(local.aws_lbc_lb_front, "name", "grafana-victoriametrics")
#   depends_on = [
#     time_sleep.wait_90_seconds,
#   ]
# }

# resource "aws_route53_record" "www" {
#   for_each = toset(["www.${local.domain_name_public}", local.domain_name_public])
#   zone_id  = data.terraform_remote_state.domain.outputs.route53_zone_zone_id_public
#   name     = each.key
#   type     = "A"

#   alias {
#     name                   = data.aws_lb.arn_dns.dns_name
#     zone_id                = data.aws_lb.arn_dns.zone_id
#     evaluate_target_health = true
#   }

#   depends_on = [
#     data.aws_lb.arn_dns
#   ]
# }
