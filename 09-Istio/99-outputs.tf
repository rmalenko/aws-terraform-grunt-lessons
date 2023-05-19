output "istio_namespace" {
  value = local.namespace
}
# output "alb_manifests" {
#   value = data.kubectl_file_documents.alb.manifests
# }

# output "aws_lb_arn" {
#   value = data.aws_lb.test.arn
#   dns_name
# }
# output "istio_ingress_node_port_health" {
#     value =   lookup(local_file.istio_ingress_var.content, "status_port_nodeport", "none")
#     # sensitive = true
# }

# output "name" {
#   value       = aws_iam_role.lbc.*.name
#   description = "The name of generated IAM role"
# }

# output "arn" {
#   value       = aws_iam_role.lbc.*.arn
#   description = "The ARN of generated IAM role"
# }

# output "kubecli" {
#   value = (var.enabled ? join(" ", [
#     format("kubectl -n %s create sa %s", local.namespace, local.serviceaccount),
#     "&&",
#     format("kubectl -n %s annotate sa %s %s",
#       local.namespace,
#       local.serviceaccount,
#       join("=", ["eks.amazonaws.com/role-arn", aws_iam_role.lbc.arn])
#     ),
#   ]) : null)
#   description = "The kubernetes configuration file for creating IAM role with service account"
# }

# output "test" {
#   value = aws_iam_policy.albingress.0.arn
#   # value = aws_iam_policy.albingress.0.arn
# }

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
