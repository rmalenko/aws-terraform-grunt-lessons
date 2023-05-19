variable "release_name" {
  description = "Helm release name for kube-state-metrics"
  type        = string
  default     = "kube-state-metrics"
}

variable "chart_name" {
  description = "Helm chart name to provision"
  type        = string
  default     = "kube-state-metrics"
}

variable "chart_repository" {
  description = "Helm repository for the chart"
  type        = string
  default     = "https://charts.bitnami.com/bitnami"
}

# https://artifacthub.io/packages/helm/bitnami/kube-state-metrics?modal=install
variable "chart_version" {
  description = "Version of Chart to install. Set to empty to install the latest version"
  type        = string
  default     = "2.2.14"
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


