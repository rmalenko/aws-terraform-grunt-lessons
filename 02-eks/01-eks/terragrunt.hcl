locals {
  # Automatically load environment-level variables
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars      = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  aws_account_id   = read_terragrunt_config(find_in_parent_folders("account.hcl"))

  # Extract out common variables for reuse
  # env = local.environment_vars.locals.environment
}

# Include all settings from the root terragrunt.hcl file
include {
  path = find_in_parent_folders()
}

inputs = {
  env             = local.environment_vars.locals.environment
  region          = local.region_vars.locals.aws_region
  aws_account_id  = local.aws_account_id.locals.aws_account_id
  s3_key_dir      = "${path_relative_to_include()}" # stage/us-west-2/01-pre-setup/iam-users-admin
  namespace       = "applications"
  # cidr_elasticcache = module.vpc.elasticache_subnets
}

terraform {
  source = ""

  # extra_arguments "common_vars" {
  #   commands = ["plan", "apply"]

  #   arguments = [
  #     "-var-file=../../common.tfvars",
  #     "-var-file=../region.tfvars"
  #   ]
  # }
}
