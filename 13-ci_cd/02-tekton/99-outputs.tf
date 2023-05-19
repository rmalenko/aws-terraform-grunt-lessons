# output "vm_release_name" {
#   value = var.vm_release_name
# }

output "persistent_volume_claim" {
  value = local.name_persistent_volume_claim
}

# output "kubernetes_config_map" {
#   value = kubernetes_config_map.victoria_alerts
# }

# output "helm_release" {
# value = helm_release.victoria_alerts.data
# value = lookup(helm_release.victoria_alerts.data, "alert-rules.yaml", default)
# sensitive = true
# }