output "aws_template_name_karpenter" {
  value = aws_launch_template.karpenter.name
}

output "aws_iam_instance_profile_name_karpenter" {
  value = aws_iam_instance_profile.karpenter.name
}