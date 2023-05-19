locals {
  cluster_name                       = data.terraform_remote_state.eks.outputs.cluster_id
  cluster_oidc_issuer_url            = data.terraform_remote_state.eks.outputs.cluster_oidc_issuer_url
  oidc_arn                           = data.terraform_remote_state.eks.outputs.oidc_provider_arn
  cluster_endpoint                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_certificate_authority_data = data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data
  efs_fileSystemId                   = data.terraform_remote_state.efs-nfs.outputs.id-efs
  kubernetes_storage_class           = "efs-sc"

  eks-owned-tag = {
    format("kubernetes.io/cluster/%s", local.cluster_name) = "owned"
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

provider "helm" {
  kubernetes {
    config_path = "~/.kube/kubeconfig-dev"
  }
}


# resource "kubernetes_csi_driver" "efs" {
#   metadata {
#     name = "efs-csi-driver"
#     annotations = {
#       name = "For store data"
#     }
#     labels = {
#       Name    = local.cluster_name
#       purpose = "victoriametrics"
#     }
#   }

#   spec {
#     attach_required        = true
#     pod_info_on_mount      = true
#     volume_lifecycle_modes = ["Persistent"]
#   }
# }

resource "kubernetes_storage_class" "efs" {
  metadata {
    name = local.kubernetes_storage_class
    labels = {
      Name    = local.cluster_name
      purpose = "victoriametrics"
    }
  }
  storage_provisioner = "efs.csi.aws.com"
  reclaim_policy      = "Retain" # Retain or Delete
  # mount_options  = ["file_mode=0700", "dir_mode=0777", "mfsymlinks", "uid=1000", "gid=1000", "nobrl", "cache=none"]
  parameters = {
    provisioningMode = "efs-ap"
    fileSystemId     = "${local.efs_fileSystemId}"
    directoryPerms   = "700"
    basePath         = "/vmdb"
  }
}

