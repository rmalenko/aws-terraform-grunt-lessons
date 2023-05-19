# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION
# Terragrunt is a thin wrapper for Terraform that provides extra tools for working with multiple Terraform modules,
# remote state, and locking: https://github.com/gruntwork-io/terragrunt
# ---------------------------------------------------------------------------------------------------------------------

# Set PATH to modules
locals {
  # Automatically load account-level variables
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))

  # Automatically load region-level variables
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  # Automatically load environment-level variables
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  # Extract the variables we need for easy access
  account_name    = local.account_vars.locals.account_name
  aws_profile     = local.account_vars.locals.aws_profile
  aws_cred_file   = local.account_vars.locals.aws_cred_file
  aws_config_file = local.account_vars.locals.aws_config_file
  account_id      = local.account_vars.locals.aws_account_id
  aws_region      = local.region_vars.locals.aws_region
  environment     = local.environment_vars.locals.environment
}

# Generate an AWS provider block
generate "provider" {
  path      = "00-provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region                   = "${local.aws_region}"
  shared_config_files      = ["${local.aws_config_file}"]
  shared_credentials_files = ["${local.aws_cred_file}"]
  profile                  = "${local.aws_profile}"
  allowed_account_ids      = ["${local.account_id}"]
}
EOF
}

# Configure Terragrunt to automatically store tfstate files in an S3 bucket
remote_state {
  backend = "s3"
  config = {
    encrypt                = true
    bucket                 = "${get_env("TG_BUCKET_PREFIX", "")}terragrunt-terraform-state-${local.account_name}-${local.aws_region}"
    dynamodb_table         = "terraform-locks-${local.aws_region}"
    key                    = "${path_relative_to_include()}/terraform.tfstate"
    region                 = local.aws_region
    profile                = local.aws_profile
    skip_bucket_versioning = true
    # shared_credentials_file = "${local.aws_cred_file}"
    s3_bucket_tags = {
      owner       = local.aws_profile
      name        = "${local.aws_profile}-state"
      environment = local.environment
    }
    dynamodb_table_tags = {
      owner       = local.aws_profile
      name        = "${local.aws_profile}-state"
      environment = local.environment
    }
  }
  generate = {
    path      = "01-backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}


# ---------------------------------------------------------------------------------------------------------------------
# GLOBAL PARAMETERS
# These variables apply to all configurations in this subfolder. These are automatically merged into the child
# `terragrunt.hcl` config via the include block.
# ---------------------------------------------------------------------------------------------------------------------

# Configure root level variables that all resources can inherit. This is especially helpful with multi-account configs
# where terraform_remote_state data sources are placed directly into the modules.
inputs = merge(
  local.account_vars.locals,
  local.region_vars.locals,
  local.environment_vars.locals,
  {
    aws_region   = local.aws_region
    region       = local.aws_region
    account_name = local.account_name
    stage        = local.environment
    profile      = local.aws_profile
  }
)

terraform {
  # Force Terraform to keep trying to acquire a lock for
  # up to 20 minutes if someone else already has the lock
  extra_arguments "retry_lock" {
    commands  = get_terraform_commands_that_need_locking()
    arguments = ["-lock-timeout=10m"]
  }
}
