output "aws-kms-ec2-key_id" {
  value = aws_kms_key.ec2.key_id
}

output "aws-kms-ec2-key_arn" {
  value = aws_kms_key.ec2.arn
}

output "aws_kms_alias_arn" {
  value = aws_kms_alias.ec2_key_alias.arn
}
