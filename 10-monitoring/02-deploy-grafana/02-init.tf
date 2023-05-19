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

data "terraform_remote_state" "efs-nfs" {
  backend = "s3"
  config = {
    profile                 = var.profile
    shared_credentials_file = "~/.aws/credentials"
    region                  = var.aws_region
    bucket                  = "terragrunt-terraform-state-${var.account_name}-${var.aws_region}/"
    key                     = "${var.env}/${var.aws_region}/12-EKS/01-initial/02-efs/terraform.tfstate"
  }
}

data "terraform_remote_state" "efs_csi_driver" {
  backend = "s3"
  config = {
    profile                 = var.profile
    shared_credentials_file = "~/.aws/credentials"
    region                  = var.aws_region
    bucket                  = "terragrunt-terraform-state-${var.account_name}-${var.aws_region}/"
    key                     = "${var.env}/${var.aws_region}/12-EKS/03-efs_csi_driver/terraform.tfstate"
  }
}

data "terraform_remote_state" "domain_name" {
  backend = "s3"
  config = {
    profile                 = var.profile
    shared_credentials_file = "~/.aws/credentials"
    region                  = var.aws_region
    bucket                  = "terragrunt-terraform-state-${var.account_name}-${var.aws_region}/"
    key                     = "${var.env}/${var.aws_region}/12-EKS/01-initial/03-R53/terraform.tfstate"
  }
}

data "terraform_remote_state" "victoriametrics" {
  backend = "s3"
  config = {
    profile                 = var.profile
    shared_credentials_file = "~/.aws/credentials"
    region                  = var.aws_region
    bucket                  = "terragrunt-terraform-state-${var.account_name}-${var.aws_region}/"
    key                     = "${var.env}/${var.aws_region}/12-EKS/10-monitoring/01-VictoriaMetrics/terraform.tfstate"
  }
}


