# zones
output "route53_zone_zone_id_public" {
  description = "Zone ID of Route53 zone"
  value       = aws_route53_zone.primary.zone_id
}

output "route53_zone_zone_id_private" {
  description = "Zone ID of Route53 zone"
  value       = aws_route53_zone.private.zone_id
}

# output "domain_name" {
#   value = local.domain_name
# }

# output "domain_private" {
#   value = local.private_zone
# }

# output "vpc_id" {
#   value = local.vpc_id
# }

