variable "istio_git_release_version" {
  default = "1.12.6"
}
variable "sleep_for_after_istio_init" {
  default = "15"
  type    = string
}

variable "helm_chart_version_istio" {
  type        = string
  description = "Istio operator Helm chart version"
  default     = "1.13.2"
}

variable "helm_repository" {
  type        = string
  default     = "https://istio-release.storage.googleapis.com/charts"
  description = "Istio repository URL."
}

variable "operator_version" {
  type        = string
  default     = "1.10.3"
  description = "Istio operator version."
}

# variable "release_name" {
#   description = "Helm release name for Grafana"
#   type        = string
#   default     = "grafana"
# }

# variable "chart_name" {
#   description = "Helm chart name to provision"
#   type        = string
#   default     = "grafana"
# }

# variable "chart_repository" {
#   description = "Helm repository for the chart"
#   type        = string
#   default     = "https://grafana.github.io/helm-charts"
# }


variable "namespace" {
  description = "The namespace where kubernetes service account is"
  type        = string
}

# variable "serviceaccount" {
#   description = "The name of kubernetes service account"
#   type        = string
# }

# variable "cluster_oidc_issuer_url" {
#   description = "A URL of the OIDC Provider"
#   type        = string
# }

# variable "oidc_arn" {
#   description = "An ARN of the OIDC Provider"
#   type        = string
# }

variable "tags" {
  description = "The key-value maps for tagging"
  type        = map(string)
  default     = {}
}

variable "policy_arns" {
  description = "A list of policy ARNs to attach the role"
  type        = list(string)
  default     = []
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

variable "account_id" {
  type = string
}

variable "profile" {
  type = string
}

variable "s3_key_dir" {
  type = string
}


