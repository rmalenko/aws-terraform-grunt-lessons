output "aws_wafv2_regex_pattern_set" {
  #   value = aws_wafv2_regex_pattern_set.http_headers.arn
  value = aws_wafv2_regex_pattern_set.http_headers.regular_expression
}

output "aws_wafv2_web_acl_arn" {
  value = aws_wafv2_web_acl.eks.arn
}

output "aws_wafv2_web_acl_id" {
  value = aws_wafv2_web_acl.eks.id
}

