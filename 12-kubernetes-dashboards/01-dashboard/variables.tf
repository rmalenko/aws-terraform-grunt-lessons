variable "helm_chart_name" {
  type        = string
  default     = "kubernetes-dashboard"
  description = "Helm chart name to be installed"
}

variable "helm_chart_version" {
  type        = string
  default     = "4.0.2"
  description = "Version of the Helm chart"
}

variable "helm_release_name" {
  type        = string
  default     = "kubernetes-dashboard"
  description = "Helm release name"
}

variable "helm_repo_url" {
  type        = string
  default     = "https://kubernetes.github.io/dashboard"
  description = "Helm repository"
}


variable "k8s_create_namespace" {
  type        = bool
  default     = true
  description = "Whether to create k8s namespace with name defined by `k8s_namespace`"
}

variable "k8s_namespace" {
  type        = string
  default     = "kubernetes-dashboard"
  description = "The k8s namespace in which the kubernetes-dashboard service account has been created"
}

variable "mod_dependency" {
  default     = null
  description = "Dependence variable binds all AWS resources allocated by this module, dependent modules reference this variable"
}

variable "settings" {
  type        = map(any)
  default     = {}
  description = "Additional settings which will be passed to the Helm chart values, see https://artifacthub.io/packages/helm/k8s-dashboard/kubernetes-dashboard"
}

# variable "cluster_name" {
#   type = string
# }

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


