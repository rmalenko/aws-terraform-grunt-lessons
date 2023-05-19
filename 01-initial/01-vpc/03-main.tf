# https://github.com/terraform-aws-modules/terraform-aws-vpc.git

locals {
  domain_name_private = "jazzfest.prz"
  domain_name_public  = "jazzfest.link"
  # service                 = "monitoring-eks"
  security_group_vpc_name = local.cluster-name
  cluster-name            = "monitoring-${var.env}"

  tags = {
    environment = "opsrnd"
    service     = local.cluster-name
    team        = "dreamteam"
    managedby   = "Terraform"
  }
}

module "vpc" {
  source          = "../../modules/terraform-aws-vpc"
  name            = local.cluster-name
  cidr            = "10.0.0.0/16"
  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  private_subnets = ["10.0.16.0/20", "10.0.32.0/20"]
  public_subnets  = ["10.0.48.0/20", "10.0.64.0/20"]
  # private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  # public_subnets  = ["10.0.4.0/24", "10.0.5.0/24"]

  enable_ipv6          = false
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  enable_flow_log                      = false
  create_flow_log_cloudwatch_iam_role  = false
  create_flow_log_cloudwatch_log_group = false

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster-name}" = "shared"
    "kubernetes.io/role/elb"                      = 1 // https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.1/deploy/subnet_discovery/
    "karpenter.sh/discovery"                      = "pub-${local.cluster-name}"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster-name}" = "shared"
    "kubernetes.io/role/internal-elb"             = 1 // https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.1/deploy/subnet_discovery/
    "karpenter.sh/discovery"                      = "private-${local.cluster-name}"
  }

  tags = local.tags
}

resource "aws_security_group" "additional" {
  name_prefix = "${local.security_group_vpc_name}-additional"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "All internal access"
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = [
      "10.0.0.0/16",
      "10.0.16.0/20",
      "10.0.32.0/20",
      "10.0.48.0/20",
      "10.0.64.0/20",
      "172.16.0.0/12",
      "192.168.0.0/16",
    ]
  }

  egress {
    description = "All outbound access"
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    # "kubernetes.io/cluster/${local.cluster-name}" = "owned" // The bug with aws-load-balancer-controller https://github.com/kubernetes-sigs/aws-load-balancer-controller/issues/1181
    "karpenter.sh/discovery"                      = local.cluster-name
  }
}
