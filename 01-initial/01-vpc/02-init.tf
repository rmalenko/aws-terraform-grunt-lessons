//////////////////////////////
// Remote states for import //
//////////////////////////////

# data "terraform_remote_state" "remote_state_elasticache" {
#   # data "terraform_remote_state" "remote_state_iam_user" {
#   backend = "s3"
#   config = {
#     region = var.aws_region
#     bucket = "terragrunt-terraform-state-${var.account_name}-${var.aws_region}/"
#     key    = "${var.env}/${var.aws_region}/00-init/04-vpc/terraform.tfstate"
#   }
# }
