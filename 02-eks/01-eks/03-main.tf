# https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html
# curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.22.0/bin/linux/amd64/kubectl && chmod +x ./kubectl && mv ./kubectl /usr/local/bin/kubectl
# https://github.com/terraform-aws-modules/terraform-aws-eks.git

locals {
  name              = replace(data.terraform_remote_state.vpc.outputs.cluster-name, "_", "-")
  # name_template     = "karp-for"
  region            = var.aws_region
  cluster_version   = "1.22"
  vpc_id            = data.terraform_remote_state.vpc.outputs.vpc_id
  intra_subnets     = data.terraform_remote_state.vpc.outputs.intra_subnets
  public_subnets    = data.terraform_remote_state.vpc.outputs.public_subnets
  private_subnets   = data.terraform_remote_state.vpc.outputs.private_subnets
  security_group_id = data.terraform_remote_state.vpc.outputs.security_group_id

  partition      = data.aws_partition.current.partition # Used to determine correct partition (i.e. - `aws`, `aws-gov`, `aws-cn`, etc.)
  ssh_key_name   = "sshkey-${local.name}-${var.aws_region}"
  ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDJZCy+wswLXFz/XaW00QQpej99ORhMLUsnesfwS4hNNZ+Ggg7DZMvVN3+Uus6YaJOpXvVxaF73HYbudMcBJEB/nYPD/tTGuI52j2xi09YTyjjzb8Bf0h8Qqu98wNHTxwkN6+2lLOabV2e9TugexTaEwe6Mjl1pvaPwwDMQNG528vi6VMbqbH5gVhl2ekMuiLhIBBalShmQBxp6XMCOkDnfNgqSct5rRrXqA+dg7CwI/nAu4gfCY2ACeHdIhK4eLn5RMh3xhKe6PYyObXA+V/yTF59/P7xSjvRIred2OrYb8Mg4p2yniDZxSHGS7XG/wBeq4c0d4DqthLhyMZL8qKrFH86t7x95rQkA3zUc0w6YX0dIN+R4vAi0f8FnyRWKahr6DMiPkv+VrxNNLZYkEQX0feEU8s5lT0qXF2PBY3WkxYG9Pz0+pqihMwhF9AEiYWFkfIU7165AOSjC1v85gUWoV5U5ii2xOPjmGHs4JdIPf75gLOxhuJ7SuYGjuLxsp1UHBmXubrGPXe9L0v/VjeQP8iRZDXhnH+JfqvKD6YXk1Y5A7p/I9KSYvBK5KT6feYAzjUlnl1hmWH6WhjfrhHy4pr3JfsrfsI2EPb/vBM6dLOeFjaDji2J3/GLrgLZpkfhzeFT4MICoUnXx5H4LAK147FqvTHf17MSq7TL7XL5Ydw== rmalenko@gmail.com"

  nodegroup_name_criticaladdonsonly = "criticaladdonsonly-"
  taints_key_criticaladdonsonly     = "CriticalAddonsOnly" # Don't change case. Look on YAML of CoreDNS
  taints_value_criticaladdonsonly   = "criticaladdonsonly"

  nodegroup_name_karpenter = "karpenter-"
  # karpenter_iam_role_arn   = module.eks.eks_managed_node_groups[local.nodegroup_name_karpenter].iam_role_arn
  # karpenter_iam_role_name = module.eks.eks_managed_node_groups[local.nodegroup_name_karpenter].iam_role_name

  # taints_key_karpenter     = "karpenter_only"
  # namespace_karpenter      = "karpenter"
  # version_karpenter        = "0.9.1"
  version_nodeexporter = "1.3.1"
  systemd_unit_name    = "node_exporter"

  ec2_ssm_kms_id  = data.terraform_remote_state.ssm_role_ec2.outputs.aws-kms-ec2-key_id
  ec2_ssm_kms_arn = data.terraform_remote_state.ssm_role_ec2.outputs.aws-kms-ec2-key_arn
  # ec2_ssm_kms_alias_arn = data.terraform_remote_state.ssm_role_ec2.outputs.aws_kms_alias_arn

  tags = {
    Example    = local.name
    GithubRepo = "terraform-aws-eks"
    GithubOrg  = "terraform-aws-modules"
  }

}

resource "null_resource" "update_profile" {
  triggers = {
    cmd_patch = "aws eks --profile rmalenko --region ${var.aws_region} update-kubeconfig --name ${module.eks.cluster_id}"
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = self.triggers.cmd_patch
  }

  depends_on = [module.eks]
}

resource "random_pet" "this" { length = 1 }

provider "kubernetes" {
  config_path = "~/.kube/kubeconfig-dev"
  # host                   = module.eks.cluster_endpoint
  # cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  # exec {
  #   api_version = "client.authentication.k8s.io/v1alpha1"
  #   command     = "aws"
  #   # This requires the awscli to be installed locally where Terraform is executed
  #   args = ["eks", "get-token", "--cluster-name", module.eks.cluster_id]
  # }
}

# provider "helm" {
#   kubernetes {
#     config_path = "~/.kube/kubeconfig-dev"
#     # host                   = module.eks.cluster_endpoint
#     # cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
#     # token                  = data.aws_eks_cluster_auth.eks.token
#   }
# }

provider "kubectl" {
  apply_retry_count      = 5
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1alpha1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_id]
  }
}

# provider "kubectl" {
#   host                   = local.cluster_endpoint
#   cluster_ca_certificate = base64decode(local.cluster_certificate_authority_data)
#   token                  = data.aws_eks_cluster_auth.default.token
#   load_config_file       = false
# }

data "aws_partition" "current" {}
# data "aws_eks_cluster" "default" { name = module.eks.cluster_id }
# data "aws_eks_cluster_auth" "default" { name = module.eks.cluster_id }
# data "aws_caller_identity" "current" {}

resource "aws_key_pair" "key_rsa" {
  key_name   = local.ssh_key_name
  public_key = local.ssh_public_key
  tags = merge(local.tags, {
    environment = var.env
    name        = "Rostyslav Malenko key"
  })
}

module "eks" {
  source                          = "../../modules/terraform-aws-eks"
  create                          = true
  cluster_name                    = local.name
  cluster_version                 = local.cluster_version
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  vpc_id                          = local.vpc_id
  subnet_ids                      = local.public_subnets # local.private_subnets local.public_subnets

  # create_aws_auth_configmap = true
  # manage_aws_auth_configmap = true

  enable_irsa = true # Required for Karpenter role below

  # We will rely only on the cluster security group created by the EKS service
  # See note below for `tags`
  create_cluster_security_group = false
  create_node_security_group    = false

  # cluster_enabled_log_types       = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # EKS cluster tags
  tags = merge(local.tags, {
    # NOTE - if creating multiple security groups with this module, only tag the
    # security group that Karpenter should utilize with the following tag
    # (i.e. - at most, only one security group should have this tag in your account)
    "karpenter.sh/discovery" = local.name
  })

  cluster_timeouts = {
    create = "1200s"
    update = "2100s"
    delete = "1800s"
  }

  eks_managed_node_group_defaults = {
    ami_type       = "AL2_x86_64"
    key_name       = aws_key_pair.key_rsa.id
    disk_size      = 25
    instance_types = ["t3.small"]

    ## We are using the IRSA created below for permissions
    ## However, we have to deploy with the policy attached FIRST (when creating a fresh cluster)
    ## and then turn this off after the cluster/node group is created. Without this initial policy,
    ## the VPC CNI fails to assign IPs and nodes cannot join the cluster
    ## See https://github.com/aws/containers-roadmap/issues/1666 for more context
    iam_role_attach_cni_policy = true
    # iam_role_attach_cni_policy = false
  }

  # Extend cluster security group rules
  cluster_security_group_additional_rules = {
    egress_nodes_ephemeral_ports_tcp = {
      description                = "To node 1025-65535"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "egress"
      source_node_security_group = true
    }
  }

  node_security_group_additional_rules = {
    # Extend node-to-node security group rules
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

  cluster_addons = {
    coredns = {
      resolve_conflicts = "OVERWRITE"
    }
    kube-proxy = {
      resolve_conflicts = "OVERWRITE"
    }
    vpc-cni = {
      resolve_conflicts        = "OVERWRITE"
      service_account_role_arn = module.vpc_cni_irsa.iam_role_arn
      # addon_version            = "v1.11.0-eksbuild.1"
    }
  }

  cluster_encryption_config = [{
    provider_key_arn = local.ec2_ssm_kms_arn
    resources        = ["secrets"]
  }]

  self_managed_node_group_defaults = {
    create_security_group = false
  }

  eks_managed_node_groups = {
    // For karpenter. We need to create this group because CoreDNS should start first. Without successfully started CoreDNS other pods won't start.
    "${local.nodegroup_name_karpenter}" = {
      name                                  = format("${local.nodegroup_name_karpenter}%s", local.name)
      cluster_ip_family                     = "ipv4"
      ami_type                              = "AL2_x86_64"
      use_name_prefix                       = true
      subnet_ids                            = local.private_subnets
      force_update_version                  = true
      public_ip                             = false
      create_security_group                 = false # We don't need the node security group since we are using the cluster-created security group, which Karpenter will also use
      attach_cluster_primary_security_group = true
      min_size                              = 1
      max_size                              = 3
      desired_size                          = 1
      description                           = "EKS managed node group for ${local.nodegroup_name_karpenter} launch"
      ebs_optimized                         = false
      disable_api_termination               = false
      enable_monitoring                     = true
      disk_size                             = 25
      instance_types                        = ["t3.medium"]
      # create_launch_template                = false
      # launch_template_name                  = ""
      bootstrap_extra_args       = "--container-runtime containerd --kubelet-extra-args '--max-pods=20'"
      capacity_type              = "ON_DEMAND" # "SPOT"
      create_iam_role            = true
      iam_role_name              = "eks-managed-node-group-${local.nodegroup_name_karpenter}"
      iam_role_use_name_prefix   = false
      iam_role_description       = "EKS managed node group ${local.nodegroup_name_karpenter} role"
      iam_role_tags              = { Purpose = "Protector of the kubelet of ${local.nodegroup_name_karpenter}" }
      iam_role_attach_cni_policy = true

      vpc_security_group_ids = [local.security_group_id]
      # bootstrap_extra_args = "--container-runtime containerd --kubelet-extra-args '--max-pods=20' --enable-docker-bridge true --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/${local.cluster_name}"

      pre_bootstrap_user_data = <<-EOT
        export CONTAINER_RUNTIME="containerd"
        export USE_MAX_PODS=true
        sudo wget https://github.com/prometheus/node_exporter/releases/download/v${local.version_nodeexporter}/node_exporter-${local.version_nodeexporter}.linux-amd64.tar.gz --output-document=/tmp/node_exporter-amd64.tar.gz 
        sudo mkdir -p /tmp/node_exporter && sudo tar xvf /tmp/node_exporter-amd64.tar.gz --directory=/tmp/node_exporter --strip-components=1
        sudo cp /tmp/node_exporter/node_exporter /usr/local/bin/node_exporter

        printf %s "[Unit]
        Description=Node Exporter
        Wants=network-online.target
        After=network-online.target

        [Service]
        Type=simple
        ExecStart=/usr/local/bin/node_exporter

        [Install]
        WantedBy=default.target
        " | sudo tee /etc/systemd/system/${local.systemd_unit_name}.service

        sudo systemctl daemon-reload; sudo systemctl enable ${local.systemd_unit_name}; sudo systemctl start ${local.systemd_unit_name}
      EOT

      labels = {
        purpose = "karpenter"
        k8s-app = "karpenter"
        type    = "managed_node_groups"
        # "elbv2.k8s.aws/pod-readiness-gate-inject" = "enabled"
        # "node.kubernetes.io/exclude-from-external-load-balancers" = true // Prevent to add to a target group by AWS Load Balancer Controller
      }

      k8s_labels = {
        purpose                                                   = "karpenter"
        k8s-app                                                   = "karpenter"
        type                                                      = "managed_node_groups"
        "elbv2.k8s.aws/pod-readiness-gate-inject"                 = "enabled"
        "node.kubernetes.io/exclude-from-external-load-balancers" = true // Prevent to add to a target group by AWS Load Balancer Controller
      }

      taints = [
        {
          key    = local.taints_key_criticaladdonsonly
          value  = local.taints_value_criticaladdonsonly
          effect = "NO_SCHEDULE"
        }
      ]

      update_config = {
        max_unavailable_percentage = 50 # or set `max_unavailable`
      }

      iam_role_additional_policies = [
        "arn:${local.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
        "arn:${local.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore", // Required by Karpenter. The policy for Amazon EC2 Role to enable AWS Systems Manager service core functionality.
        "arn:${local.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy",
        "arn:${local.partition}:iam::aws:policy/AmazonEKS_CNI_Policy"
        # "arn:${local.partition}:iam::aws:policy/AmazonEC2ReadOnlyAccess",      // Provides read only access to Amazon EC2 via the AWS Management Console.
      ]
    }

    # // For criticals Add0ns
    # "${local.nodegroup_name_criticaladdonsonly}" = {
    #   name                                  = format("${local.nodegroup_name_criticaladdonsonly}%s", local.name)
    #   cluster_ip_family                     = "ipv4"
    #   ami_type                              = "AL2_x86_64"
    #   use_name_prefix                       = true
    #   subnet_ids                            = local.private_subnets
    #   force_update_version                  = true
    #   public_ip                             = false
    #   create_security_group                 = false # We don't need the node security group since we are using the cluster-created security group, which Karpenter will also use
    #   attach_cluster_primary_security_group = true
    #   min_size                              = 2
    #   max_size                              = 6
    #   desired_size                          = 2
    #   description                           = "EKS managed node group for ${local.nodegroup_name_criticaladdonsonly} launch"
    #   ebs_optimized                         = true
    #   disable_api_termination               = false
    #   enable_monitoring                     = true
    #   disk_size                             = 25
    #   instance_types                        = ["t3.small"]
    #   # create_launch_template                = false
    #   # launch_template_name                  = ""
    #   bootstrap_extra_args       = "--container-runtime containerd --kubelet-extra-args '--max-pods=20'"
    #   capacity_type              = "ON_DEMAND" # "SPOT"
    #   create_iam_role            = true
    #   iam_role_name              = "eks-managed-node-group-${local.nodegroup_name_criticaladdonsonly}"
    #   iam_role_use_name_prefix   = false
    #   iam_role_description       = "EKS managed node group ${local.nodegroup_name_criticaladdonsonly} role"
    #   iam_role_tags              = { Purpose = "Protector of the kubelet of ${local.nodegroup_name_criticaladdonsonly}" }
    #   iam_role_attach_cni_policy = true

    #   vpc_security_group_ids = [local.security_group_id]
    #   # bootstrap_extra_args = "--container-runtime containerd --kubelet-extra-args '--max-pods=20' --enable-docker-bridge true --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/${local.cluster_name}"

    #   pre_bootstrap_user_data = <<-EOT
    #     export CONTAINER_RUNTIME="containerd"
    #     export USE_MAX_PODS=true
    #     sudo wget https://github.com/prometheus/node_exporter/releases/download/v${local.version_nodeexporter}/node_exporter-${local.version_nodeexporter}.linux-amd64.tar.gz --output-document=/tmp/node_exporter-amd64.tar.gz 
    #     sudo mkdir -p /tmp/node_exporter && sudo tar xvf /tmp/node_exporter-amd64.tar.gz --directory=/tmp/node_exporter --strip-components=1
    #     sudo cp /tmp/node_exporter/node_exporter /usr/local/bin/node_exporter

    #     printf %s "[Unit]
    #     Description=Node Exporter
    #     Wants=network-online.target
    #     After=network-online.target

    #     [Service]
    #     Type=simple
    #     ExecStart=/usr/local/bin/node_exporter

    #     [Install]
    #     WantedBy=default.target
    #     " | sudo tee /etc/systemd/system/${local.systemd_unit_name}.service

    #     sudo systemctl daemon-reload; sudo systemctl enable ${local.systemd_unit_name}; sudo systemctl start ${local.systemd_unit_name}
    #   EOT

    #   labels = {
    #     purpose = "criticaladdonsonly"
    #     k8s-app = "criticaladdonsonly"
    #     type    = "managed_node_groups"
    #     # "elbv2.k8s.aws/pod-readiness-gate-inject" = "enabled"
    #     # "node.kubernetes.io/exclude-from-external-load-balancers" = true // Prevent to add to a target group by AWS Load Balancer Controller
    #   }

    #   k8s_labels = {
    #     purpose                                                   = "criticaladdonsonly"
    #     k8s-app                                                   = "criticaladdonsonly"
    #     type                                                      = "managed_node_groups"
    #     "elbv2.k8s.aws/pod-readiness-gate-inject"                 = "enabled"
    #     "node.kubernetes.io/exclude-from-external-load-balancers" = true // Prevent to add to a target group by AWS Load Balancer Controller
    #   }

    #   taints = [
    #     {
    #       key    = local.taints_key_criticaladdonsonly # Don't change case. Look on YAML of CoreDNS
    #       value  = "criticaladdonsonly"
    #       effect = "NO_SCHEDULE"
    #     }
    #   ]

    #   update_config = {
    #     max_unavailable_percentage = 50 # or set `max_unavailable`
    #   }

    #   iam_role_additional_policies = [
    #     "arn:${local.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    #     "arn:${local.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore", // Required by Karpenter. The policy for Amazon EC2 Role to enable AWS Systems Manager service core functionality.
    #     "arn:${local.partition}:iam::aws:policy/AmazonEC2ReadOnlyAccess",      // Provides read only access to Amazon EC2 via the AWS Management Console.
    #   ]
    # }

  }
}

module "vpc_cni_irsa" {
  source                = "../../modules/terraform-aws-iam/modules/iam-role-for-service-accounts-eks"
  role_name_prefix      = "VPC-CNI-IRSA"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true
  # vpc_cni_enable_ipv6   = true
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }
  tags = local.tags
}

// systems-manager - START
// https://docs.aws.amazon.com/systems-manager/latest/userguide/session-preferences-enable-encryption.html
//
// https://us-east-1.console.aws.amazon.com/systems-manager/session-manager/preferences?region=us-east-1
// Session Manager - allows get an instance console if public IP isn't enabled.
// Check in Preferences if KMS encryption enabled and KMS  key selected correct.

// Attached Policy to role on eks_managed_node_groups
resource "aws_iam_role_policy_attachment" "ssm_role_ec2" {
  for_each   = module.eks.eks_managed_node_groups
  policy_arn = aws_iam_policy.ec2_ssm_kms.arn
  role       = each.value.iam_role_name
}

// Grant access to each of roles from eks_managed_node_groups
// aws_kms_key - should be previously created in ./01-initial/04-KMS/03-main.tf
resource "aws_kms_grant" "ec2" {
  for_each          = module.eks.eks_managed_node_groups
  name              = "ec2-ssm-${local.name}"
  key_id            = local.ec2_ssm_kms_id
  grantee_principal = module.eks.eks_managed_node_groups[each.key].iam_role_arn
  operations        = ["Encrypt", "Decrypt", "GenerateDataKey"]
}

resource "aws_iam_policy" "ec2_ssm_kms" {
  name        = "ec2_ssm_kms"
  path        = "/"
  description = "Allows a role use KMS key"

  policy = jsonencode(
    {
      "Version" = "2012-10-17",
      "Statement" = [
        {
          "Sid"    = "VisualEditor0",
          "Effect" = "Allow",
          "Action" = [
            "kms:GetPublicKey",
            "kms:Decrypt",
            "kms:Encrypt",
            "kms:GenerateDataKey"
          ],
          "Resource" = "${local.ec2_ssm_kms_arn}"
        },
        {
          "Sid"    = "VisualEditor1",
          "Effect" = "Allow",
          "Action" = [
            "kms:DescribeCustomKeyStores",
            "kms:ListKeys",
            "kms:ListAliases"
          ],
          "Resource" = "*"
        }
      ]
    }
  )
  tags = {
    tag-key = "tag-value"

  }
}
// systems-manager - END