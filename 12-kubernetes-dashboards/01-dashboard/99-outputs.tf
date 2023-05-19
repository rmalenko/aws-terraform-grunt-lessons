# output "helm_release_attributes" {
#   description = "Helm release attributes"
#   value       = helm_release.kubernetes_dashboard
#   sensitive   = true
# }

output "dashboard_url" {
  value = "http://localhost:8001/api/v1/namespaces/${local.namespace_kubernetes_dashboard}/services/https:kubernetes-dashboard:https/proxy"
}

output "namespace_kubernetes_dashboard" {
  value = local.namespace_kubernetes_dashboard
}

# output "kubeconfig" {
#   value = abspath("${path.root}/${local_file.kubeconfig.filename}")
# }

# output "dashboard_url" {
#   value = module.aws-eks-dashboard.dashboard_url
# }

# output "name_space" {
#   value = kubernetes_namespace.victoriametrics
# }

# output "kubernetes_csi_driver" {
#   value = kubernetes_csi_driver.efs.id
# }


# output "test" {
#   value = local.test
# }
# output "aws_eks_cluster" {
#   value = data.aws_eks_cluster.default.endpoint
# }

# output "aws_eks_cluster_auth" {
#   value     = data.aws_eks_cluster_auth.default.token
#   sensitive = true
# }

# output "cluster_certificate_authority_data" {
#   value = local.cluster_certificate_authority_data
# }
