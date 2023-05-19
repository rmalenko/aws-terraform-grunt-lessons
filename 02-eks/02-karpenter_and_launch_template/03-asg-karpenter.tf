# https://karpenter.sh/
# https://aws.github.io/aws-eks-best-practices/karpenter/
# https://kubesandclouds.com/index.php/2022/01/04/karpenter-vs-cluster-autoscaler/

locals {
  oidc_provider_arn             = data.terraform_remote_state.eks.outputs.oidc_provider_arn
  oidc_provider                 = data.terraform_remote_state.eks.outputs.oidc_provider
  karpenter_iam_role_arn        = data.terraform_remote_state.eks.outputs.karpenter_iam_role_arn
  karpenter_iam_role_name       = data.terraform_remote_state.eks.outputs.karpenter_iam_role_name
  cluster_id                    = data.terraform_remote_state.eks.outputs.cluster_id
  cluster_endpoint              = data.terraform_remote_state.eks.outputs.cluster_endpoint
  taints_key_criticaladdonsonly = data.terraform_remote_state.eks.outputs.taints_key_criticaladdonsonly
  partition                     = data.aws_partition.current.partition # Used to determine correct partition (i.e. - `aws`, `aws-gov`, `aws-cn`, etc.)
  namespace_karpenter           = "karpenter"
  version_karpenter             = "0.10.1"
  cluster_name                  = replace(data.terraform_remote_state.vpc.outputs.cluster-name, "_", "-")

  tags = {
    Name = local.cluster_name
  }

}

data "aws_partition" "current" {}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/kubeconfig-dev"
  }
}

resource "null_resource" "helm_repo" {
  provisioner "local-exec" {
    command = <<EOF
    set -xe
    cd ${path.root}
    rm -rf ./karpenter-${local.version_karpenter} || true
    wget https://charts.karpenter.sh/karpenter-${local.version_karpenter}.tgz && tar -xvzf karpenter-${local.version_karpenter}.tgz
    # rm -rf ./karpenter || true
    # mv ./karpenter-${local.version_karpenter} karpenter
    EOF
  }

  triggers = {
    build_number = local.version_karpenter
  }
}

resource "aws_iam_role" "karpenter_controller" {
  name        = "Karpenter-controller-of-eks-${local.cluster_name}"
  description = "Karpenter controller role of kubernetes cluster ${local.cluster_name}"
  path        = "/"
  tags        = local.tags
  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Sid" : "",
          "Effect" : "Allow",
          "Principal" : {
            "Federated" : local.oidc_provider_arn
          },
          "Action" : "sts:AssumeRoleWithWebIdentity",
          "Condition" : {
            "StringEquals" : {
              "${local.oidc_provider}:aud" : "sts.amazonaws.com",
              "${local.oidc_provider}:sub" : "system:serviceaccount:${local.namespace_karpenter}:${local.namespace_karpenter}"
            }
          }
        }
      ]
    }
  )
}

resource "aws_iam_policy" "karpenter_controller" {
  name        = "EKS_Karpenter_Controller_Policy-${local.cluster_name}"
  path        = "/"
  description = "Allows Karpenter to launch a new instance"
  tags        = local.tags
  policy = jsonencode(
    {
      "Statement" : [
        {
          "Action" : [
            "ec2:DescribeSubnets",
            "ec2:DescribeSecurityGroups",
            "ec2:DescribeLaunchTemplates",
            "ec2:DescribeInstances",
            "ec2:DescribeInstanceTypes",
            "ec2:DescribeInstanceTypeOfferings",
            "ec2:DescribeAvailabilityZones",
            # "ec2:Describe*",
            "ec2:CreateTags",
            "ec2:CreateLaunchTemplate",
            "ec2:CreateFleet"
          ],
          "Effect" : "Allow",
          "Resource" : "*",
          "Sid" : ""
        },
        {
          "Action" : [
            "ec2:TerminateInstances",
            "ec2:DeleteLaunchTemplate"
          ],
          "Condition" : {
            "StringEquals" : {
              "ec2:ResourceTag/karpenter.sh/discovery" : local.cluster_name
            }
          },
          "Effect" : "Allow",
          "Resource" : "*",
          "Sid" : ""
        },
        {
          "Action" : "ec2:RunInstances",
          "Effect" : "Allow",
          "Resource" : [
            "arn:${local.partition}:ec2:*::image/*",
            "arn:${local.partition}:ec2:*:${var.aws_account_id}:volume/*",
            "arn:${local.partition}:ec2:*:${var.aws_account_id}:subnet/*",
            "arn:${local.partition}:ec2:*:${var.aws_account_id}:security-group/*",
            "arn:${local.partition}:ec2:*:${var.aws_account_id}:network-interface/*",
            "arn:${local.partition}:ec2:*:${var.aws_account_id}:launch-template/*",
            "arn:${local.partition}:ec2:*:${var.aws_account_id}:key-pair/*",
            "arn:${local.partition}:ec2:*:${var.aws_account_id}:instance/*",
          ],
          "Sid" : ""
        },
        {
          "Action" : "ssm:GetParameter",
          "Effect" : "Allow",
          "Resource" : "${var.karpenter_controller_ssm_parameter_arns}"
          "Sid" : ""
        },
        {
          "Action" : "iam:PassRole",
          "Effect" : "Allow",
          "Resource" : "${local.karpenter_iam_role_arn}"
          "Sid" : ""
        }
      ],
      "Version" : "2012-10-17"
    }
  )
}

resource "aws_iam_role_policy_attachment" "karpenter_controller" {
  role       = aws_iam_role.karpenter_controller.name
  policy_arn = aws_iam_policy.karpenter_controller.arn
}

# https://github.com/aws/karpenter/tree/main/charts/karpenter
resource "aws_iam_instance_profile" "karpenter" {
  name = "KarpenterNodeInstanceProfile-${local.cluster_name}"
  role = local.karpenter_iam_role_name
}

resource "helm_release" "karpenter" {
  namespace        = local.namespace_karpenter
  create_namespace = true
  name             = "karpenter"
  repository       = "https://charts.karpenter.sh"
  chart            = "karpenter"
  version          = local.version_karpenter

  dynamic "set" {
    for_each = {
      "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn" = aws_iam_role.karpenter_controller.arn
      "clusterName"                                               = local.cluster_id
      "clusterEndpoint"                                           = local.cluster_endpoint
      "serviceAccount.name"                                       = local.namespace_karpenter
      "aws.defaultInstanceProfile"                                = aws_iam_instance_profile.karpenter.name
      "tolerations[0].key"                                        = local.taints_key_criticaladdonsonly
      "tolerations[0].value"                                      = "criticaladdonsonly"
      "tolerations[0].operator"                                   = "Equal"
      "tolerations[0].effect"                                     = "NoSchedule"
    }
    content {
      name  = set.key
      value = set.value
    }
  }
}

# // Critical. This provisioner will create capacity as long as the sum of all created capacity is less than the specified limit.
# resource "kubectl_manifest" "karpenter_provisioner" {
#   yaml_body = <<-YAML
#   apiVersion: karpenter.sh/v1alpha5
#   kind: Provisioner
#   metadata:
#     name: criticaladdonsonly-karpenter
#   spec:
#     taints:
#       - key: "${local.taints_key_criticaladdonsonly}"
#         effect: NoSchedule
#     labels:
#       purpose: criticaladdonsonly
#       managed-by: karpenter
#     requirements:
#       - key: karpenter.sh/capacity-type
#         operator: In
#         # values: ["spot"]
#         # values: ["spot", "on-demand"]
#         values: ["on-demand"]
#       - key: "topology.kubernetes.io/zone" 
#         operator: In
#         values: ["${var.aws_region}a", "${var.aws_region}b"]
#       - key: "kubernetes.io/arch" 
#         operator: In
#         values: ["arm64", "amd64"]
#       - key: "node.kubernetes.io/instance-type"
#         operator: In
#         values: ["t3.micro", "t3.small", "t3.medium", "t3.large", "c5.xlarge", "c5.2xlarge", "c5.2xlarge", "m5.large", "m5.xlarge"]
#     limits:
#       resources:
#         cpu: 100
#         memory: 1000Gi
#     provider:
#       launchTemplate: "${aws_launch_template.karpenter.name}"
#       # instanceProfile: "${aws_iam_instance_profile.karpenter.name}"
#       subnetSelector:
#         karpenter.sh/discovery: "private-${local.cluster_name}"
#         # karpenter.sh/discovery: "pub-${local.cluster_name}"
#       # securityGroupSelector:
#       #   karpenter.sh/discovery: "${local.cluster_name}"
#       tags:
#         karpenter.sh/discovery: "${local.cluster_name}"
#         Name: "criticaladdonsonly-${local.cluster_name}"
#     # If omitted, the feature is disabled and nodes will never expire.  If set to less time than it requires for a node
#     # to become ready, the node may expire before any pods successfully start.
#     # ttlSecondsUntilExpired: 2592000 # 30 Days = 60 * 60 * 24 * 30 Seconds;

#     # If omitted, the feature is disabled, nodes will never scale down due to low utilization
#     ttlSecondsAfterEmpty: 30
#   YAML

#   depends_on = [
#     aws_launch_template.karpenter,
#     helm_release.karpenter
#   ]
# }

