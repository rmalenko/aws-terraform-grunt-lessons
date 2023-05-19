//////////////////////////////
// Remote states for import //
//////////////////////////////

data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    profile                 = var.profile
    shared_credentials_file = "~/.aws/credentials"
    region                  = var.aws_region
    bucket                  = "terragrunt-terraform-state-${var.account_name}-${var.aws_region}/"
    key                     = "${var.env}/${var.aws_region}/12-EKS/02-eks/01-eks/terraform.tfstate"
  }
}

data "terraform_remote_state" "karpenter_and_launch_template" {
  backend = "s3"
  config = {
    profile                 = var.profile
    shared_credentials_file = "~/.aws/credentials"
    region                  = var.aws_region
    bucket                  = "terragrunt-terraform-state-${var.account_name}-${var.aws_region}/"
    key                     = "${var.env}/${var.aws_region}/12-EKS/02-eks/02-karpenter_and_launch_template/terraform.tfstate"
  }
}

data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    profile                 = var.profile
    shared_credentials_file = "~/.aws/credentials"
    region                  = var.aws_region
    bucket                  = "terragrunt-terraform-state-${var.account_name}-${var.aws_region}/"
    key                     = "${var.env}/${var.aws_region}/12-EKS/01-initial/01-vpc/terraform.tfstate"
  }
}

data "terraform_remote_state" "waf" {
  backend = "s3"
  config = {
    profile                 = var.profile
    shared_credentials_file = "~/.aws/credentials"
    region                  = var.aws_region
    bucket                  = "terragrunt-terraform-state-${var.account_name}-${var.aws_region}/"
    key                     = "${var.env}/${var.aws_region}/12-EKS/02-eks/04-WAF/terraform.tfstate"
  }
}

data "terraform_remote_state" "domain" {
  backend = "s3"
  config = {
    profile                 = var.profile
    shared_credentials_file = "~/.aws/credentials"
    region                  = var.aws_region
    bucket                  = "terragrunt-terraform-state-${var.account_name}-${var.aws_region}/"
    key                     = "${var.env}/${var.aws_region}/12-EKS/01-initial/03-R53/terraform.tfstate"
  }
}
