variable "vm_release_name" {
  description = "Helm release name for VictoriaMetrics"
  default     = "victoria-metrics-single"
}

variable "vm_chart" {
  description = "Chart for VictoriaMetrics"
  default     = "victoria-metrics-single"
}

variable "vm_chart_repository_url" {
  description = "Chart Repository URL for VictoriaMetrics"
  default     = "https://victoriametrics.github.io/helm-charts/"
}

variable "vm_chart_version" {
  description = "Chart version for VictoriaMetrics"
  default     = "0.8.28"
}


variable "vm_release_name_alerts" {
  description = "Helm release name for Victoria Metrics Alert"
  default     = "victoria-metrics-alert"
}

variable "vm_chart_alerts" {
  description = "Chart for VictoriaMetrics"
  default     = "victoria-metrics-alert"
}

variable "vm_chart_version_alerts" {
  description = "Chart version for Victoria Metrics Alert"
  default     = "0.4.24"
}


variable "alertmanager_release_name" {
  description = "Helm release name for alertmanager"
  default     = "alertmanager"
}

variable "alertmanager_chart" {
  description = "Chart for alertmanager"
  default     = "alertmanager"
}

variable "alertmanager_chart_repository_url" {
  description = "Chart Repository URL for alertmanager"
  default     = "https://prometheus-community.github.io/helm-charts"
}

variable "alertmanager_chart_version" {
  description = "Chart version for alertmanager"
  default     = "0.15.0"
}

variable "max_history" {
  description = "Max history for Helm"
  type        = number
  default     = 10
}

# variable "victoria_tolerations" {
#   description = "Tolerations for VictoriaMetrics Select server"
#   type        = list(map(string))
# type = list(any)
#   default = [
#     {
#       key      = "k8s-app",
#       operator = "Equal",
#       value    = "grafana",
#       effect   = "NoSchedule"
#     }
#   ]
# default     = <<EOF
# tolerations:
#   - key: k8s-app
#     operator: Equal
#     value: grafana
#     effect: NoSchedule
# EOF
# type        = map(string)
# default = {
#   "key"      = "k8s-app"
#   "operator" = "Equal"
#   "value"    = "grafana"
#   "effect"   = "NoSchedule"
# }
# default = [<<EOF
#     key: k8s-app
#     operator: Equal
#     value: grafana
#     effect: NoSchedule
#     EOF
# ]
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

variable "api_url_critical" {
  type    = string
  default = ""
}

variable "api_url_warning" {
  type    = string
  default = ""
}

variable "aws_profile" {
  type = string
}