variable "tekton_release_name" {
  description = "Helm release name for argo-cd"
  default     = "argo-cd"
}

variable "tekton_chart" {
  description = "Chart for argo-cd"
  default     = "argo-cd"
}

variable "tekton_chart_repository_url" {
  description = "Chart Repository URL for argo-cd"
  default     = "https://argoproj.github.io/argo-helm"
}

variable "tekton_chart_version" {
  description = "Chart version for argo-cd"
  default     = "4.6.5"
}

variable "max_history" {
  description = "Max history for Helm"
  type        = number
  default     = 10
}

variable "env" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "account_name" {
  type = string
}

variable "profile" {
  type = string
}

variable "s3_key_dir" {
  type = string
}

variable "api_url_critical" {
  type    = string
  default = ""
}

variable "api_url_warning" {
  type    = string
  default = ""
}

variable "force_destroy" {
  description = "Flag to determine whether storage buckets get forcefully destroyed. If set to false, empty the bucket first in the aws s3 console, else terraform destroy will fail with BucketNotEmpty error"
  type        = bool
  default     = false
}

variable "use_vault" {
  type    = bool
  default = false
}

variable "use_asm" {
  type    = bool
  default = true
}