output "vm_release_name" {
  value = var.vm_release_name
}

output "persistent_volume_claim" {
  value = local.name_persistent_volume_claim
}

output "tolerations_key" {
  value = local.tolerations_key
}

output "tolerations_value" {
  value = local.tolerations_value
}

output "namespace_victoria" {
  value = local.namespace_victoria
}
