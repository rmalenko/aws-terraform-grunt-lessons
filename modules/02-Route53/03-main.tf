resource "aws_route53_zone" "primary" {
  name = var.domain_name
  tags = {
    environment = "opsrnd"
  }
}

resource "aws_route53_zone" "private" {
  name    = var.private_domain
  comment = "Managed by Terraform"
  vpc {
    vpc_id = var.vpc_id_private
  }
  tags = var.tags
}


# resource "aws_route53_record" "s3-public" {
#   zone_id = local.zone_id
#   name    = "files.${local.domain_public}"
#   type    = "A"

#   alias {
#     name                   = aws_s3_bucket.tinker-blog-wp.website_endpoint
#     zone_id                = aws_s3_bucket.tinker-blog-wp.hosted_zone_id
#     evaluate_target_health = true
#   }

#   depends_on = [
#     aws_s3_bucket.tinker-blog-wp
#   ]
# }

# resource "aws_route53_record" "tinker-wp-blog" {
#   zone_id = var.zone_id_private
#   name    = var.efs_domain_private
#   type    = "CNAME"
#   ttl     = "5"
#   records = [aws_efs_mount_target.tinker-wp-blog.dns_name]
#   depends_on = [
#     aws_efs_mount_target.tinker-wp-blog
#   ]
# }
