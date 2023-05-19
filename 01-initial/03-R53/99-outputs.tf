# # zones
output "route53_zone_zone_id_public" {
  description = "Zone ID of Route53 zone"
  value       = aws_route53_zone.primary.zone_id
}

output "route53_zone_zone_id_private" {
  description = "Zone ID of Route53 zone"
  value       = aws_route53_zone.private.zone_id
}

output "NS-primary" {
  value = aws_route53_zone.primary.name_servers
}

output "NS-private" {
  value = aws_route53_zone.private.name_servers
}

# output "aws_route53_zone" {
#   value = data.aws_route53_zone.selected
# }

output "domain_name" {
  value = local.domain_name_public
}

output "domain_private" {
  value = local.domain_name_private
}

output "vpc_id" {
  value = local.vpc_id
}

output "acm_certificate_arn" {
  description = "The ARN of the certificate"
  value       = module.acm_certificates.acm_certificate_arn
}

output "acm_certificate_domain_validation_options" {
  description = "A list of attributes to feed into other resources to complete certificate validation. Can have more than one element, e.g. if SANs are defined. Only set if DNS-validation was used."
  value       = module.acm_certificates.acm_certificate_domain_validation_options
}

output "acm_certificate_validation_emails" {
  description = "A list of addresses that received a validation E-Mail. Only set if EMAIL-validation was used."
  value       = module.acm_certificates.acm_certificate_validation_emails
}

output "validation_route53_record_fqdns" {
  description = "List of FQDNs built using the zone domain and name."
  value       = module.acm_certificates.validation_route53_record_fqdns
}

output "distinct_domain_names" {
  description = "List of distinct domains names used for the validation."
  value       = module.acm_certificates.distinct_domain_names
}

output "validation_domains" {
  description = "List of distinct domain validation options. This is useful if subject alternative names contain wildcards."
  value       = module.acm_certificates.validation_domains
}

output "domain_name_public" {
  value = local.domain_name_public
}
