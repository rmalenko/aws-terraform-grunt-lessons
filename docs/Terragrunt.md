# Terragrunt
[Terragrunt](https://terragrunt.gruntwork.io/) is a thin wrapper that provides extra tools for keeping your configurations DRY, working with multiple Terraform modules, and managing remote state. 

Structure of configuration of a project on stage
```bash
├── stage
│   ├── account.hcl
│   ├── env.hcl
│   └── us-east-1
│       ├── application
│       │   └── terragrunt.hcl
│       ├── common.hcl
│       └── region.hcl
├── terragrunt.hcl
```

## terragrunt.hcl - main

```hcl
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
    arguments = ["-lock-timeout=20m"]
  }
}

```


## account.hcl

```hcl
# Set account-wide variables. These are automatically pulled in to configure the remote state bucket in the root
# terragrunt.hcl configuration.
locals {
  account_name    = "rnd"
  aws_account_id  = "714151"
  aws_profile     = "user"
  aws_cred_file   = "${get_env("HOME")}/.aws/credentials"
  aws_config_file = "${get_env("HOME")}/.aws/config"
}

```

## env.hcl
```hcl
# Set common variables for the environment. This is automatically pulled in in the root terragrunt.hcl configuration to
# feed forward to the child modules.
locals {
  environment = "rnd"
}
```

## common.hcl
```hcl
# Set common variables for the region. This is automatically pulled in in the root terragrunt.hcl configuration to
# configure the remote state bucket and pass forward to the child modules as inputs.
locals {
  aws_region = "us-east-1"
  environment = "stage"
}
```

## region.hcl
```hcl
# Set common variables for the region. This is automatically pulled in in the root terragrunt.hcl configuration to
# configure the remote state bucket and pass forward to the child modules as inputs.
locals {
  aws_region = "us-east-1"
}
```

## terragrunt.hcl - in an application folder
```hcl
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
```

# ./.bashrc 
```bash
alias tgplan='terragrunt plan -lock=false -refresh=false'
alias tgapply='terragrunt apply --auto-approve'
alias tginit='unlink ./.terraform.lock.hcl ; terraform init -upgrade ; find . \( -name "\.terraform" -o -name ".DS_Store" -o -name ".terraform.lock.hcl" \) -exec xattr -w com.dropbox.ignored 1 {} \;'
alias tgfmt='terraform fmt' # terraform fmt -check -diff terraform fmt -recursive
alias tgvalidate='terraform validate'
alias tgout='terragrunt output'
alias tgdestroy='terragrunt destroy'
```