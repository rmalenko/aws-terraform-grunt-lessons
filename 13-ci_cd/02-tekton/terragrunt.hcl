locals {
  # Automatically load environment-level variables
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars      = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  # Extract out common variables for reuse
  # env = local.environment_vars.locals.environment
}

# Include all settings from the root terragrunt.hcl file
include {
  path = find_in_parent_folders()
}

inputs = {
  env        = local.environment_vars.locals.environment
  region     = local.region_vars.locals.aws_region
  s3_key_dir = "${path_relative_to_include()}" # stage/us-west-2/01-pre-setup/iam-users-admin
  namespace  = "applications"
  # cidr_elasticcache = module.vpc.elasticache_subnets
}


terraform {
  source = ""

  extra_arguments "custom_vars" {
    commands = [
      "apply",
      "plan",
      "apply-all",
    ]

    # An add additional variables to use but prevents to accidentally bring to a repo.
    optional_var_files = [
      "${get_env("HOME")}/.aws/additional.tfvars"
    ]
  }
}
