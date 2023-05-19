# Creates a KMS key and role with policies that can use this key to get access to an EC2 instance through AWS Systems Manager.
# That policy's ARN is used in ASG Launch Configurations.

locals {
  cluster_name = replace(data.terraform_remote_state.vpc.outputs.cluster-name, "_", "-")
  tags         = { "env" = var.env }
}

resource "aws_kms_key" "ec2" {
  description             = "KMS key EC2 for EKS cluster ${local.cluster_name}"
  key_usage               = "ENCRYPT_DECRYPT"
  is_enabled              = true
  enable_key_rotation     = true
  deletion_window_in_days = 7
  tags                    = local.tags
}

resource "aws_kms_alias" "ec2_key_alias" {
  name          = "alias/e8ks-${local.cluster_name}"
  target_key_id = aws_kms_key.ec2.key_id
}

# resource "aws_ssm_document" "session_manager_prefs" {
#   name            = "SSM-SessionManagerRunShell"
#   document_type   = "Session"
#   document_format = "JSON"

#   content = <<DOC
# jsonencode({
#     "schemaVersion": "1.0",
#     "description": "Document to hold regional settings for Session Manager",
#     "sessionType": "Standard_Stream",
#     "inputs": {
#         "s3BucketName": "",
#         "s3KeyPrefix": "",
#         "s3EncryptionEnabled": true,
#         "cloudWatchLogGroupName": "",
#         "cloudWatchEncryptionEnabled": true,
#         "cloudWatchStreamingEnabled": false,
#         "kmsKeyId": "${aws_kms_key.ec2.key_id}",
#         "runAsEnabled": false,
#         "runAsDefaultUser": "",
#         "idleSessionTimeout": "",
#         "maxSessionDuration": "",
#         "shellProfile": {
#             "windows": "date",
#             "linux": "timestamp=$(date '+%Y-%m-%dT%H:%M:%SZ');user=$(whoami);echo $timestamp && echo "Welcome $user"'!'"
#         }
#     }
# })
# DOC
# }

# "linux": "pwd;ls"