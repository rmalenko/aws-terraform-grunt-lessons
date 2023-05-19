# https://docs.aws.amazon.com/eks/latest/userguide/eks-optimized-ami.html

# aws ssm get-parameter --profile rmalenko --region us-east-1 --name /aws/service/eks/optimized-ami/1.22/amazon-linux-2/recommended/image_id --query "Parameter.Value" --output text
# https://docs.aws.amazon.com/eks/latest/userguide/eks-optimized-amis.html
# https://docs.aws.amazon.com/eks/latest/userguide/eks-optimized-ami.html

locals {
  name_template = "karp-for"

  userdata_val = {
    version_nodeexporter   = "1.3.1"
    systemd_unit_name      = "node_exporter"
    cluster_name           = local.cluster_name
    cluster_ca_certificate = "${data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data}"
    cluster_endpoint       = "${data.terraform_remote_state.eks.outputs.cluster_endpoint}"
    karpenter_key          = "karpenter.sh/discovery"
  }

  tag_template_specifications = {
    instance = {
      resource_type = "instance"
      tags = {
        "karpenter.sh/discovery" = local.cluster_name
      }
    },
    volume = {
      resource_type = "volume"
      tags = {
        "karpenter.sh/discovery" = local.cluster_name
      }
    },
    # spot = {
    #   resource_type = "spot-instances-request"
    #   # tags          = merge({ WhatAmI = "SpotInstanceRequest" }, local.tags_as_map)
    #   tags = { WhatAmI = "SpotInstanceRequest" }
    # },
  }
}

data "aws_ssm_parameter" "eks_optimized_ami" {
  name = "/aws/service/eks/optimized-ami/1.22/amazon-linux-2/recommended/image_id"
}

resource "aws_launch_template" "karpenter" {
  name_prefix             = local.name_template
  description             = "Launch template for EKS karpenter"
  ebs_optimized           = false
  image_id                = data.aws_ssm_parameter.eks_optimized_ami.value
  key_name                = data.terraform_remote_state.eks.outputs.aws_key_pair
  user_data               = base64encode(templatefile("${path.module}/templates/userdata_for_template_ec2.sh", local.userdata_val))
  vpc_security_group_ids  = [data.terraform_remote_state.vpc.outputs.security_group_id, data.terraform_remote_state.eks.outputs.cluster_primary_security_group_id]
  update_default_version  = true
  disable_api_termination = false

  iam_instance_profile {
    name = aws_iam_instance_profile.karpenter.name
  }

  dynamic "block_device_mappings" {
    for_each = var.ebs_block_device_name
    content {
      device_name  = try(block_device_mappings.value.device_name, null)
      no_device    = try(block_device_mappings.value.no_device, null)
      virtual_name = lookup(block_device_mappings.value, "virtual_name", null)

      dynamic "ebs" {
        for_each = flatten([lookup(block_device_mappings.value, "ebs", [])])
        content {
          delete_on_termination = try(ebs.value.delete_on_termination, null)
          encrypted             = try(ebs.value.encrypted, null)
          kms_key_id            = try(ebs.value.kms_key_id, null)
          iops                  = try(ebs.value.iops, null)
          throughput            = try(ebs.value.throughput, null)
          snapshot_id           = try(ebs.value.snapshot_id, null)
          volume_size           = try(ebs.value.volume_size, null)
          volume_type           = try(ebs.value.volume_type, null)
        }
      }
    }
  }

  monitoring {
    enabled = true
  }

  # placement {
  #   availability_zone = local.region
  #   group_name        = data.terraform_remote_state.placement_group.outputs.aws_placement_group_partition_name
  # }

  dynamic "tag_specifications" {
    for_each = local.tag_template_specifications
    content {
      resource_type = tag_specifications.value.resource_type
      tags          = tag_specifications.value.tags
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  # tags = var.tags_as_map
}
