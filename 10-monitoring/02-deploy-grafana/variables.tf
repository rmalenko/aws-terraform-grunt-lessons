variable "release_name" {
  description = "Helm release name for Grafana"
  type        = string
  default     = "grafana"
}

variable "chart_name" {
  description = "Helm chart name to provision"
  type        = string
  default     = "grafana"
}

variable "chart_repository" {
  description = "Helm repository for the chart"
  type        = string
  default     = "https://grafana.github.io/helm-charts"
}

# variable "chart_namespace" {
#   description = "Namespace to install the chart into"
#   type        = string
#   default     = "default"
# }

# https://github.com/grafana/helm-charts/releases
variable "chart_version" {
  description = "Version of Chart to install. Set to empty to install the latest version"
  type        = string
  default     = "6.24.1"
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


