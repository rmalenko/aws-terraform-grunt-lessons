// Istio. This provisioner will create capacity as long as the sum of all created capacity is less than the specified limit.
resource "kubectl_manifest" "karpenter_provisioner" {
  yaml_body = <<-YAML
  apiVersion: karpenter.sh/v1alpha5
  kind: Provisioner
  metadata:
    name: istio-karpenter
  spec:
    taints:
      - key: "${local.tolerations_key}"
        value: "${local.tolerations_value}"
        effect: NoSchedule
    labels:
      "${local.tolerations_key}": "${local.tolerations_value}"
      managed-by: karpenter
    requirements:
      - key: karpenter.sh/capacity-type
        operator: In
        values: ["on-demand"]
      - key: "topology.kubernetes.io/zone" 
        operator: In
        values: ["${var.aws_region}a", "${var.aws_region}b"]
      - key: "kubernetes.io/arch" 
        operator: In
        values: ["arm64", "amd64"]
      - key: "node.kubernetes.io/instance-type"
        operator: In
        values: ["t3.small", "c5.large", "c5.xlarge", "c5.2xlarge", "c5.2xlarge"]
    limits:
      resources:
        cpu: 50
        memory: 512Gi
    provider:
      launchTemplate: "${local.aws_template_name_karpenter}"
      subnetSelector:
        karpenter.sh/discovery: "private-${local.cluster_name}"
        # karpenter.sh/discovery: "pub-${local.cluster_name}"
      tags:
        karpenter.sh/discovery: "${local.cluster_name}"
        Name: "istio-${local.cluster_name}"
        "${local.tolerations_key}": "${local.tolerations_value}"
    ttlSecondsAfterEmpty: 30
  YAML
}