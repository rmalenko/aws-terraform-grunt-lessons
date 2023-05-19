locals {
  domain_name_public  = data.terraform_remote_state.vpc.outputs.domain_name_public
  domain_name_private = data.terraform_remote_state.vpc.outputs.domain_name_private
  vpc_id              = data.terraform_remote_state.vpc.outputs.vpc_id
  use_failback        = false

  failback_list = [
    "aws-dns-1",
    "aws-dns-2",
    "aws-dns-3",
    "aws-dns-4",
  ]

  tags = {
    Name        = local.domain_name_public
    environment = "opsrnd"
    domain      = local.domain_name_public
    team        = "dreamteam"
    managedby   = "Terraform"
  }
}

resource "aws_route53_zone" "primary" {
  name = local.domain_name_public
  tags = {
    environment = "opsrnd"
  }
}

resource "aws_route53_zone" "private" {
  name    = local.domain_name_private
  comment = "Managed by Terraform"
  vpc {
    vpc_id = local.vpc_id
  }
  tags = {
    environment = "opsrnd"
  }
}

resource "null_resource" "update-ns-domain" {
  triggers = {
    nameservers = join(", ", sort(local.use_failback == false ? aws_route53_zone.primary.name_servers : [for ns in local.failback_list : ns]))
  }
  provisioner "local-exec" {
    command = "aws route53domains update-domain-nameservers --region ${var.aws_region} --profile ${var.profile} --domain-name ${local.domain_name_public} --nameservers  ${join(" ", formatlist(" Name=%s", sort(local.use_failback == false ? aws_route53_zone.primary.name_servers : [for ns in local.failback_list : ns])))}   "
  }
}

module "acm_certificates" {
  source              = "../../modules/terraform-aws-acm"
  domain_name         = local.domain_name_public
  zone_id             = aws_route53_zone.primary.zone_id
  wait_for_validation = true
  tags                = local.tags

  subject_alternative_names = [
    "*.${local.domain_name_public}"
  ]
}
