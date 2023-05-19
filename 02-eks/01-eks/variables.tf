# variable "aws_vpc_id" {
#   default = "vpc-03ed65d03bad1d9b7"
# }

variable "env" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "account_name" {
  type = string
}

variable "aws_account_id" {
  type = string
}

variable "profile" {
  type = string
}

variable "s3_key_dir" {
  type = string
}

variable "ebs_block_device_name" {
  description = "Specify volumes to attach to the instance besides the volumes specified by the AMI"
  type        = map(any)
  default = {
    ebs00_root = {
      no_device    = "0"
      device_name  = "/dev/xvda"
      virtual_name = "root_and_boot"
      ebs = {
        volume_size           = 50
        volume_type           = "gp3"
        iops                  = 3000
        throughput            = 150
        delete_on_termination = true
        encrypted             = false
      }
    }
    # ebs01 = {
    #   no_device   = "1"
    #   device_name = "/dev/xvdb"
    #   ebs = {
    #     delete_on_termination = true
    #     encrypted             = false
    #     # kms_key_id            = ""
    #     # iops                  = ""
    #     # throughput            = ""
    #     # snapshot_id           = ""
    #     volume_size = 25
    #     volume_type = "gp3"
    #   }
    # },
    # ebs01 = {
    #   no_device             = "1"
    #   device_name           = "/dev/xvdb"
    #   delete_on_termination = true
    #   encrypted             = false
    #   volume_size           = 20
    #   volume_type           = "gp3"
    # }
  }
}

variable "karpenter_controller_ssm_parameter_arns" {
  description = "List of SSM Parameter ARNs that contain AMI IDs launched by Karpenter"
  type        = list(string)
  # https://github.com/aws/karpenter/blob/ed9473a9863ca949b61b9846c8b9f33f35b86dbd/pkg/cloudprovider/aws/ami.go#L105-L123
  default = ["arn:aws:ssm:*:*:parameter/aws/service/*"]
}
