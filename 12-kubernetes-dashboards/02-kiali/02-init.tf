//////////////////////////////
// Remote states for import //
//////////////////////////////

data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    profile                 = "rmalenko"
    shared_credentials_file = "~/.aws/credentials"
    region                  = var.aws_region
    bucket                  = "terragrunt-terraform-state-${var.account_name}-${var.aws_region}/"
    key                     = "${var.env}/${var.aws_region}/12-EKS/02-eks/terraform.tfstate"
  }
}

data "terraform_remote_state" "namespace_kube_dashb" {
  backend = "s3"
  config = {
    profile                 = "rmalenko"
    shared_credentials_file = "~/.aws/credentials"
    region                  = var.aws_region
    bucket                  = "terragrunt-terraform-state-${var.account_name}-${var.aws_region}/"
    key                     = "${var.env}/${var.aws_region}/12-EKS/11-kubernetes-dashboards/01-dashboard/terraform.tfstate"
  }
}

data "terraform_remote_state" "istio" {
  backend = "s3"
  config = {
    profile                 = "rmalenko"
    shared_credentials_file = "~/.aws/credentials"
    region                  = var.aws_region
    bucket                  = "terragrunt-terraform-state-${var.account_name}-${var.aws_region}/"
    key                     = "${var.env}/${var.aws_region}/12-EKS/09-Istio/terraform.tfstate"
  }
}
