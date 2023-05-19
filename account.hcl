# Set account-wide variables. These are automatically pulled in to configure the remote state bucket in the root
# terragrunt.hcl configuration.
locals {
  account_name    = "rnd"
  aws_account_id  = "7141"
  aws_profile     = "r"
  aws_cred_file   = "${get_env("HOME")}/.aws/credentials"
  aws_config_file = "${get_env("HOME")}/.aws/config"
}
