output "dns_of_efs_mount_target" {
  # value = aws_efs_mount_target.victoriametrics.dns_name
  value = aws_efs_file_system.victoriametrics.dns_name
}

# output "domain_efs" {
#   value = aws_route53_record.tinker-wp-blog.fqdn
# }

output "number_of_mount_targets" {
  value = aws_efs_file_system.victoriametrics.number_of_mount_targets
}

output "size_in_bytes" {
  value = aws_efs_file_system.victoriametrics.size_in_bytes
}

output "ARN-efs_victoriametrics" {
  value       = aws_efs_file_system.victoriametrics.arn
  description = "EFS ARN"
}

output "id-efs" {
  value       = aws_efs_file_system.victoriametrics.id
  description = "EFS ID"
}

# output "efs_fqdn_private" {
#   value = aws_efs_file_system.tinker-wp-blog.dns_name
# }

# output "all" {
#   value = aws_efs_mount_target.tinker-wp-blog
# }

# output "access_point_ids" {
#   value       = { for id in sort(keys(local.access_points)) : id => aws_efs_access_point.victoriametrics[id].id }
#   description = "EFS AP ids"
# }

# output "access_point_arns" {
#   value       = { for arn in sort(keys(local.access_points)) : arn => aws_efs_access_point.victoriametrics[arn].arn }
#   description = "EFS AP ARNs"
# }

output "access_points_victoriametrics" {
  value = local.access_points_victoriametrics
}

output "access_points_grafana" {
  value = local.access_points_grafana
}

output "mount_target_efs" {
  value = {
    for dns in sort(keys(aws_efs_mount_target.victoriametrics)) : dns => aws_efs_mount_target.victoriametrics[dns].dns_name
  }
  description = "EFS mount targets DNS"
}
