variable "asg_name" {
  default = "test-web"
  type    = string
}

# variable "ebs_block_device" {
#   description = "Specify volumes to attach to the instance besides the volumes specified by the AMI"
#   type        = map(any)
#   default = {
#     ebs00 = {
#       # no_device             = "0"
#       device_name           = "/dev/xvdb"
#       delete_on_termination = true
#       encrypted             = false
#       volume_size           = 30
#       volume_type           = "gp3"
#     },
#     # ebs01 = {
#     #   device_name           = "/dev/xvdc"
#     #   no_device             = "0"
#     #   delete_on_termination = true
#     #   encrypted             = false
#     #   volume_size           = 30
#     #   volume_type           = "gp3"
#     # }
#   }
# }

# variable "root_block_device" {
#   description = "Customize details about the root block device of the instance"
#   type        = map(any)
#   default = {
#     root = {
#       delete_on_termination = true
#       encrypted             = false
#       volume_size           = "15"
#       volume_type           = "gp3"
#     }
#   }
# }

# variable "ephemeral_block_device" {
#   description = "Customize Ephemeral (also known as 'Instance Store') volumes on the instance"
#   type        = map(any)
#   default = {
#     ephemeral = {
#       device_name  = "/dev/xvdd"
#       virtual_name = "ephemeral1"
#     }
#   }
# }

// https://docs.aws.amazon.com/autoscaling/ec2/userguide/lifecycle-hooks.html?icmpid=docs_ec2as_console#preparing-for-notification
// https://docs.aws.amazon.com/cli/latest/reference/autoscaling/describe-lifecycle-hook-types.html#examples
variable "initial_lifecycle_hooks" {
  description = "One or more Lifecycle Hooks to attach to the Auto Scaling Group before instances are launched. The syntax is exactly the same as the separate `aws_autoscaling_lifecycle_hook` resource, without the `autoscaling_group_name` attribute. Please note that this will only work when creating a new Auto Scaling Group. For all other use-cases, please use `aws_autoscaling_lifecycle_hook` resource"
  type        = map(any)
  default = {
    launch = {
      name                 = "StartupLifeCycleHook"
      default_result       = "CONTINUE"
      heartbeat_timeout    = "120"
      lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCHING"
      # notification_metadata   = "hello world"
      # notification_target_arn = "arn"
      # role_arn                = "arn"
    },
    terminate = {
      name                 = "TerminateLifeCycleHook"
      default_result       = "CONTINUE"
      heartbeat_timeout    = "300"
      lifecycle_transition = "autoscaling:EC2_INSTANCE_TERMINATING"
      # notification_metadata   = "hello world"
      # notification_target_arn = "arn"
      # role_arn                = "arn"
    },
    # launch_error = {
    #   name                 = "LaunchErrorLifeCycleHook"
    #   default_result       = "CONTINUE"
    #   heartbeat_timeout    = "300"
    #   lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCH_ERROR"
    #   # notification_metadata   = "hello world"
    #   # notification_target_arn = "arn"
    #   # role_arn                = "arn"
    # },
    # terminate_error = {
    #   name                 = "TerminateErrorLifeCycleHook"
    #   default_result       = "CONTINUE"
    #   heartbeat_timeout    = "300"
    #   lifecycle_transition = "autoscaling:EC2_INSTANCE_TERMINATE_ERROR"
    #   # notification_metadata   = "hello world"
    #   # notification_target_arn = "arn"
    #   # role_arn                = "arn"
    # },
  }
}

// https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-warm-pools.html
variable "warm_pool" {
  description = "(Optional) Sets the instances pool state to transition to after the lifecycle hooks finish."
  type        = map(any)
  default = {
    pool00 = {
      // Sets the instance state to transition to after the lifecycle hooks finish. Valid values are: Stopped (default) or Running.
      pool_state = "Stopped"
      // Specifies the minimum number of instances to maintain in the warm pool. This helps you to ensure that there is always a certain number of warmed instances available to handle traffic spikes. Defaults to 0 if not specified.
      min_size = 0
      // Specifies the total maximum number of instances that are allowed to be in the warm pool or in any state except Terminated for the Auto Scaling group.
      max_group_prepared_capacity = 2
    },
  }
}


variable "instances_number" {
  description = "NUmber of instances"
  type        = number
  default     = 2
}

variable "env" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "account_name" {
  type = string
}

variable "profile" {
  type = string
}

variable "s3_key_dir" {
  type = string
}

# None — Prevents the instances from launching into a Capacity Reservation. The instances run in On-Demand capacity.
# Open — Launches the instances into any Capacity Reservation that has matching attributes and sufficient capacity for the number of instances you selected. If there is no matching Capacity Reservation with sufficient capacity, the instance uses On-Demand capacity.
variable "capacity_reservation_preference" {
  description = "Launch instances into an existing Capacity Reservation"
  type        = string
  default     = "none"
}

# Target by ID — Launches the instances into the selected Capacity Reservation. If the selected Capacity Reservation does not have sufficient capacity for the number of instances you selected, the instance launch fails.
# Target by group — Launches the instances into any Capacity Reservation with matching attributes and available capacity in the selected Capacity Reservation group. If the selected group does not have a Capacity Reservation with matching attributes and available capacity, the instances launch into On-Demand capacity.


variable "ec2tags" {
  description = "Additional resource tags"
  type        = map(any)
  default = {
    environment = {
      value = "opsrnd"
    },
    name = {
      value = "asg"
    },
    managedby = {
      value = "terraform"
    },
    application = {
      value = "web"
    }
  }
}
