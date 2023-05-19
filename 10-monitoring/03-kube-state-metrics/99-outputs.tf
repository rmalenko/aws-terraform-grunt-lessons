# output "login" {
#   description = "The login is:"
#   value       = random_password.grafana_admin_password[0].result
#   sensitive   = true
# }

# output "passwords" {
#   description = "The password is:"
#   value       = random_password.grafana_admin_password[1].result
#   sensitive   = true
# }

# output "name_persistent_volume_claim" {
#   value = local.name_persistent_volume_claim
# }
