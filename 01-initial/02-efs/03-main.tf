locals {
  private_subnets               = data.terraform_remote_state.vpc.outputs.private_subnets
  public_subnets                = data.terraform_remote_state.vpc.outputs.public_subnets
  security_group_id             = data.terraform_remote_state.vpc.outputs.security_group_id
  root_directory                = toset(["victoriametrics", "grafana"])
  cluster_name                  = data.terraform_remote_state.vpc.outputs.cluster-name
  access_points_victoriametrics = "victoriametrics"
  access_points_grafana         = "grafana"
  access_points_argocd          = "argocd"

  posix_users = {
    for k, v in local.access_points :
    k => lookup(local.access_points[k], "posix_user", {})
  }

  secondary_gids = {
    for k, v in local.access_points :
    k => lookup(local.posix_users, "secondary_gids", null)
  }

  access_points = {
    "${local.access_points_victoriametrics}" = {
      posix_user = {
        gid            = "1001"
        uid            = "5000"
        secondary_gids = "1002,1003"
      }
      creation_info = {
        gid         = "1001"
        uid         = "5000"
        permissions = "0755"
      }
    }
    "${local.access_points_grafana}" = {
      posix_user = {
        gid            = "2001"
        uid            = "6000"
        secondary_gids = "2002,2003"
      }
      creation_info = {
        gid         = "2001"
        uid         = "6000"
        permissions = "0755"
      }
    }
    "${local.access_points_argocd}" = {
      posix_user = {
        gid            = "2001"
        uid            = "6000"
        secondary_gids = "2002,2003"
      }
      creation_info = {
        gid         = "2001"
        uid         = "6000"
        permissions = "0755"
      }
    }
  }

  tags = {
    Name        = "monitoring"
    environment = "opsrnd"
    service     = "monitoring"
    application = "victoriametrics"
    managedby   = "Terraform"
  }

}

# resource "kubernetes_csi_driver" "efs" {
#   metadata {
#     name      = "${local.cluster_name}-monitoring"
#     # namespace = local.namespace_victoria
#     annotations = {
#       name = "For store data of VictoriaMetrics and Grafana."
#     }
#     labels = {
#       Name    = local.cluster_name
#       purpose = "victoriametrics"
#     }
#   }
# }

# resource "kubernetes_storage_class" "efs" {
#   metadata {
#     name = "efs-sc-${local.cluster_name}-monitoring"
#   }
#   # storage_provisioner = kubernetes_csi_driver.efs.metadata[0].name
#   storage_provisioner = kubernetes_csi_driver.efs.id
#   reclaim_policy      = "Retain"
#   mount_options       = ["file_mode=0700", "dir_mode=0777", "mfsymlinks", "uid=1000", "gid=1000", "nobrl", "cache=none"]
#   # parameters = {
#   #   type = "pd-standard"
#   # }
# }

resource "aws_efs_file_system" "victoriametrics" {
  creation_token   = "victoriametrics"
  encrypted        = true
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  tags             = local.tags
  # kms_key_id       = var.kms_key
  # availability_zone_name = var.efs_one_availability_zone // If setup one zone EC2 instances from other zones won't able to have access. ALB require minimum two zones. I.e. this leads to an error mounting EFS on EC2 instances from another zone.
}


## Disabled because neds to install aws-efs-csi-driver https://github.com/kubernetes-sigs/aws-efs-csi-driver/tree/master/examples/kubernetes/access_points
## to use mount EFS Access Points and needs minimum two instances.
## --------------------------------------------------------------------------------------------------
resource "aws_efs_access_point" "victoriametrics" {
  for_each       = local.access_points
  file_system_id = aws_efs_file_system.victoriametrics.id

  dynamic "posix_user" {
    for_each = local.posix_users[each.key] != null ? ["true"] : []

    content {
      gid            = local.posix_users[each.key]["gid"]
      uid            = local.posix_users[each.key]["uid"]
      secondary_gids = local.secondary_gids[each.key] != null ? split(",", local.secondary_gids[each.key]) : null
    }
  }

  root_directory {
    path = "/${each.key}"

    dynamic "creation_info" {
      for_each = try(lookup(local.access_points[each.key]["creation_info"]["gid"], ""), "") != "" ? ["true"] : []

      content {
        owner_gid   = local.access_points[each.key]["creation_info"]["gid"]
        owner_uid   = local.access_points[each.key]["creation_info"]["uid"]
        permissions = local.access_points[each.key]["creation_info"]["permissions"]
      }
    }
  }

  tags = local.tags
}

resource "aws_efs_backup_policy" "victoriametrics" {
  file_system_id = aws_efs_file_system.victoriametrics.id
  backup_policy {
    status = "DISABLED"
  }
}

resource "aws_efs_file_system_policy" "victoriametrics" {
  file_system_id = aws_efs_file_system.victoriametrics.id

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Id": "efs-policy-wizard-d56b0314-997f-420a-91ca-16ab4e6ea0fd",
    "Statement": [
        {
            "Sid": "efs-statement-d7f23466-b78a-4b50-8dfd-c0312ad31724",
            "Effect": "Allow",
            "Principal": {
                "AWS": "*"
            },
            "Action": [
                "elasticfilesystem:ClientRootAccess",
                "elasticfilesystem:ClientWrite",
                "elasticfilesystem:ClientMount"
            ],
            "Resource": "${aws_efs_file_system.victoriametrics.arn}",
            "Condition": {
                "Bool": {
                    "elasticfilesystem:AccessedViaMountTarget": "true"
                }
            }
        }
    ]
}
POLICY
}

resource "aws_efs_mount_target" "victoriametrics" {
  # for_each        = toset(local.private_subnets)
  for_each        = toset(local.public_subnets)
  file_system_id  = aws_efs_file_system.victoriametrics.id
  security_groups = [local.security_group_id]
  subnet_id       = each.key
}
