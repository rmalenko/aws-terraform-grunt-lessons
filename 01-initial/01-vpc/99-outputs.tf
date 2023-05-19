
output "intra_subnets" {
  value = module.vpc.intra_subnets
}

output "private_subnets" {
  value = module.vpc.private_subnets
}

output "public_subnets" {
  value = module.vpc.public_subnets
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "random_pet" {
  # value = random_pet.this.id
  value = var.env
}

output "security_group_id" {
  # value = module.security_group.security_group_id
  value = aws_security_group.additional.id
}

# output "service" {
#   value = local.cluster-name
# }

output "cluster-name" {
  value       = local.cluster-name
  description = "The cluster name used in VPS subnets tag for https://kubernetes-sigs.github.io/aws-load-balancer-controller/"
}

output "domain_name_public" {
  value = local.domain_name_public
}

output "domain_name_private" {
  value = local.domain_name_private
}

# output "zone_id_public" {
#   value = module.route53.route53_zone_zone_id_public
# }

# output "acm_certificate_arn" {
#   value = module.acm_certificates.acm_certificate_arn
# }

# output "route53_zone_zone_id_private" {
#   value = module.route53.route53_zone_zone_id_private
# }
