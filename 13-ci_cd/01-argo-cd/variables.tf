variable "argo-cd_release_name" {
  description = "Helm release name for argo-cd"
  default     = "argo-cd"
}

variable "argo-cd_chart" {
  description = "Chart for argo-cd"
  default     = "argo-cd"
}

variable "argo-cd_chart_repository_url" {
  description = "Chart Repository URL for argo-cd"
  default     = "https://argoproj.github.io/argo-helm"
}

variable "argo-cd_chart_version" {
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

variable "aws_profile" {
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

# variable "repositories" {
#   description = "A list of repository defintions"
#   default     = {}
#   type = map(object({
#     url           = string
#     type          = optional(string)
#     username      = optional(string)
#     password      = optional(string)
#     sshPrivateKey = optional(string)
#   }))
# }

variable "image_tag" {
  description = "Image tag to install"
  default     = null
  type        = string
}

variable "config" {
  default     = {}
  description = "Additional config to be added to the Argocd configmap"
}

variable "server_insecure" {
  description = "Whether to run the argocd-server with --insecure flag. Useful when disabling argocd-server tls default protocols to provide your certificates"
  default     = false
}

variable "values_files" {
  type        = list(string)
  default     = []
  description = "Path to values files be passed to the Argocd Helm Deployment"
}