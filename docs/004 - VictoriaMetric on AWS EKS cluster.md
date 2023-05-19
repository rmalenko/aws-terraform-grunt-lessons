# VictoriaMetric on AWS EKS cluster
We use [Terragrunt](Terragrunt).

## Structure
`./terraform/rnd/us-east-1/12-EKS`

- [01-initial](#01-initial)
	- [01-vpc](#01-vpc)
	- [02-efs](#02-efs)
	- [03-R53](03-R53)
	- [04-KMS](04-KMS)
- [02-eks](#02-eks)
	- [Karpenter](#Karpenter)
	- [02-karpenter_and_launch_template ](#Karpenter_and_launch_template)
	- [03-efs_csi_driver](#03-efs_csi_driver)
- [08-WAF](#08-WAF)
- [09-Istio](#09-Istio)
- [10-monitoring](#10-monitoring)
	- [01-VictoriaMetrics](#01-VictoriaMetrics)
	- [02-deploy-grafana](#02-deploy-grafana)
	- [03-kube-state-metrics](#03-kube-state-metrics)
- [12-kubernetes-dashboards](#12-kubernetes-dashboards)
	- [01-dashboard](#01-dashboard)
	- [02-kiali](#02-kiali)


- modules
	- 02-Route53
	- [terraform-aws-acm](https://github.com/terraform-aws-modules/terraform-aws-acm.git)
	- [terraform-aws-eks](https://github.com/terraform-aws-modules/terraform-aws-eks.git)
	- [terraform-aws-eks-efs-csi-driver](https://github.com/DNXLabs/terraform-aws-eks-efs-csi-driver.git)
	- [terraform-aws-iam](https://github.com/terraform-aws-modules/terraform-aws-iam.git)
	- [terraform-aws-vpc](https://github.com/terraform-aws-modules/terraform-aws-vpc.git)


![](https://raw.githubusercontent.com/apptopia/ops-metricsmanager/main/terraform/stage/us-east-1/12-EKS/docs/eks.drawio.png?token=GHSAT0AAAAAABSPVEGGZUUMHRPSLGTYQSOKYUD2YZQ)

## 01-initial
### 01-vpc
[Module creates a VPC resources on AWS.](https://github.com/terraform-aws-modules/terraform-aws-vpc)

Sets these variables to use in future steps

```hcl
locals {
  domain_name_private     = "a domain name for DHCP" # it's not obligatory
  domain_name_public      = "a public domain name"
  security_group_vpc_name = "${local.service}-${var.env}"
  cluster-name            = "monitoring-${var.env}" # cluster's name

  tags = {
    environment = "opsrnd"
    service     = local.service
    team        = "dreamteam"
    managedby   = "Terraform"
  }
}
```

If you need, you may add more regions as you wish.
```hcl
  cidr            = "10.0.0.0/16"
  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.4.0/24", "10.0.5.0/24"]
```

`public_subnets` - allows egress (out) from pods to the Internet.

**Important:** It needs to tag the Amazon VPC subnets in an Amazon EKS cluster for automatic subnet discovery by load balancers or ingress controllers. [Subnet tagging](https://docs.aws.amazon.com/eks/latest/userguide/network_reqs.html).
[How can I automatically discover the subnets used by my Application Load Balancer in Amazon EKS?](https://aws.amazon.com/premiumsupport/knowledge-center/eks-subnet-auto-discovery-alb/)


### 02-efs
Will create EFS for use as volume mounts. Pods that use this EFS should write their own data into their own folder to avoid messing all files into the root folder.

*Possible improving*. [Amazon EFS CSI Driver](https://github.com/kubernetes-sigs/aws-efs-csi-driver). This Driver can automatically create an access point for each Persistent Volume

### 03-R53

Creates DNS records for the domain defined in [01-vpc](#01-vpc) and issues an SSL certificate for its.

### 04-KMS
 Create a KMS key for getting access to EC2 instances' shells that don't have a public IP address.

## 02-eks
The configuration creates an EKS cluster using module [AWS EKS (Kubernetes) resources](https://github.com/terraform-aws-modules/terraform-aws-eks)
Add to `~/.bashrc` `export KUBECONFIG=~/.kube/kubeconfig-dev`

This file `~/.kube/kubeconfig-dev` has sensitive information that provides access to your cluster on AWS. This file will be created the running of this configuration. 

To get access to a cluster, use this code.

```hcl
provider "kubernetes" {
  config_path = "~/.kube/kubeconfig-dev"
}
```

In this module, we use `eks_managed_node_groups` - EKS managed node group.
These are: 
- grafana - For Grafana. One server in a group
- victoria_metrics - one server in the group for Victoriametrics one server
- istio-system - min 1, max 3 servers in a group for Istio
- criticaladdonsonly - min 2, max 3 for CoreDNS and Victoriametrics Alert and Alertmanager.

Each of these servers uses user data to install node_exporter.

This setup allows being flexible. For example, Grafana needs more memory than a powerful CPU, Victoriametrics quite the opposite needs a more powerful CPU and memory. And Istio needs CPU and memory,, more pods and could be under high loads. Alertmanager needs less memory, but CoreDNS needs average CPU and memory but needs more pods to run.

To set corresponded server's groups for applications we use:
```hcl
taints = [
        {
          key    = "CriticalAddonsOnly"
          value  = "criticaladdonsonly"
          effect = "NO_SCHEDULE"
        }
      ]
```

In this example, we allow egress traffic `subnet_ids`. 
```hcl
...
eks_managed_node_groups = {
    grafana- = {
      name = format("grafana-%s", local.cluster_name)
      # ami_id               = data.aws_ami.eks_default.image_id
      ami_type             = "AL2_x86_64"
      use_name_prefix      = true
      subnet_ids           = local.public_subnets
...
```


We use the module [Create IAM role for service accounts (IRSA) for use within EKS clusters](https://github.com/terraform-aws-modules/terraform-aws-iam) for [Amazon VPC Container Network Interface (CNI) plugin for Kubernetes](https://docs.aws.amazon.com/eks/latest/userguide/pod-networking.html)

Also, we create a policy allowing to get an EC2 instance console if public IP isn't enabled.
[Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-preferences-enable-encryption.html)

### Karpenter_and_launch_template 
Template is used to launch a new instance to have nodeexporter for monitoring.
An AMI is looked in amazon-linux-2 v. 1.22. The newest version you may find [Amazon EKS optimized Amazon Linux AMIs](https://docs.aws.amazon.com/eks/latest/userguide/eks-optimized-ami.html)

```hcl
data "aws_ssm_parameter" "eks_optimized_ami" {
  name = "/aws/service/eks/optimized-ami/1.22/amazon-linux-2/recommended/image_id"
}
```



### 03-efs_csi_driver
[Amazon EFS CSI driver](https://docs.aws.amazon.com/eks/latest/userguide/efs-csi.html) provides a CSI interface that allows Kubernetes clusters running on AWS to manage the lifecycle of Amazon [EFS file systems](https://docs.aws.amazon.com/efs/latest/ug/whatisefs.html).

## 08-WAF
[Web Application Firewall](https://aws.amazon.com/waf/) - uses for AWS ALB.

## 09-Istio
This code installs [Istio Simplify observability, traffic management, security, and policy with the leading service mesh.](https://istio.io/) and [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/).

### Istio
- istio_discovery 
- istio_ingress
- istio_egress
- istio_operator

In order to take advantage of all of Istio’s features, pods in the mesh must be running an Istio sidecar proxy. Add label `istio-injection = "enabled"`
```hcl
resource "kubernetes_namespace" "victoriametrics" {
  metadata {
    name = local.namespace_victoria
    annotations = {
      name            = local.namespace_victoria
      istio-injection = "enabled"
    }
    labels = {
      Name            = local.namespace_victoria
      purpose         = local.namespace_victoria
      istio-injection = "enabled"
    }
  }
  depends_on = [module.eks]
}
```

[Installing the Sidecar](https://istio.io/latest/docs/setup/additional-setup/sidecar-injection/)
[Resource Annotations](https://istio.io/latest/docs/reference/config/annotations/)
[Demystifying Istio's Sidecar Injection Model](https://istio.io/latest/blog/2019/data-plane-setup/)
[Enabling sidecar injection](https://docs.openshift.com/container-platform/4.6/service_mesh/v2x/prepare-to-deploy-applications-ossm.html)

### AWS Load Balancer Controller

Install from the Helm repo AWS Load Balancer Controller and add Ingress using rules from 
`./09-Istio/templates/alb-internet-facing.yml` These rules provide configuration to create ALB (application LB).
This configuration uses:
- WAF
- Domain Certificate
- Target type `instance` in a target group
- Configured to add into the target group instances tagged by `istio_system_toleration_key_name = istio-system_toleration_value` to avoid add all instances.
As result, we should to have automatically created ALB which will redirect HTTP requests to HTPPS and to nodes with Istio where traffic will route from, following the rules which already configured.


[Subnet Auto Discovery](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/deploy/subnet_discovery/)

In `./01-initial/01-vpc/03-main.tf` set tags

```hcl
public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster-name}" = "shared"
    "kubernetes.io/role/elb"                      = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster-name}" = "shared"
    "kubernetes.io/role/internal-elb"             = 1
  }
```

[AWS ALB controller](AWS_Load_Balancer_Controller)

### DNS
Add to DNS zone records `local.domain_name_public`  This value `domain_name_public` defined in [01-vpc](#01-vpc)

## 10-monitoring
Sets of monitoring tools

### 01-VictoriaMetrics
[VictoriaMetrics single server.](#https://github.com/VictoriaMetrics/VictoriaMetrics/wiki/Single-server-VictoriaMetrics) This should be enough for a big cluster. And VictoriaMetricshas better performance than Prometheus. 

**However**, VictoriaMetrics cluster isn't a real cluster of time series DB. It lacks replications of data and if a node in this cluster down a cluster needs to manually restore db from backup. It means not enough redundancy. So, it needs looks another solution for an enormous cluster. It was reason why we don't use VictoriaMetrics Cluster server.

VictoriaMetrics helm and discovery values - `./victoria_helm_values.yaml`

**Important**, `./terragrunt.hcl ` - has the code:
```hcl
terraform {
  source = ""

  extra_arguments "custom_vars" {
    commands = [
      "apply",
      "plan",
      "apply-all",
    ]

    # An add additional variables to use but prevents to accidentally bring to a repo.
    optional_var_files = [
      "${get_env("HOME")}/.aws/additional.tfvars"
    ]
  }
}
```

It allows getting variables and avoid putting it into a repository by inconsiderate. The `additional.tfvars` looks like:

```bash
api_url_critical = "https://hooks.slack.com/services/TE/B2/5s"
api_url_warning  = "https://hooks.slack.com/services/TE/B8/sQ"

```


Jobs:
- victoriametrics
- kubernetes-apiservers
- kubernetes-nodes
- kubernetes-nodes-cadvisor
- kubernetes-service-endpoints
- kubernetes-service-endpoints-slow
- kubernetes-services
- kubernetes-pods
- istiod
- envoy-stats
- node-exporter
- kube-state-metrics
- vmalert
- alertmanager

Alert rules - `./victoria-alerts-config-map-rules.yaml`

Alert groups:
- vm-health
- vmsingle
- vmagent
- Kubernetes kube-state-metrics
- Istio Embedded exporter
- CoreDNS Embedded exporter
- Nodeexporter Host and hardware node-exporter


### 02-deploy-grafana

Usual and well known [Grafana](https://grafana.com/). After successfully finished run the code, you may find administrative level credentials in the file user_credentials_grafana.txt

Dashboards which will be available:
- VictoriaMetrics - vmalert
- VictoriaMetrics single
- Node Exporter Full
- Kubernetes / Views / Namespaces
- Kubernetes / System / API Server
- Kubernetes / System / API Server
- kubernetes-persistent-volumes
- Prometheus / Overview
- Node Exporter / Nodes
- Kubernetes Overview
- Kubernetes / System / CoreDNS
- CoreDNS
- Alertmanager / Overview
- Kubernetes / Views / Global
- Istio Workload Dashboard
- Istio Service Dashboard
- Istio Mesh Dashboard
- Istio Control Plane Dashboard


 
### 03-kube-state-metrics
[kube-state-metrics](#https://github.com/kubernetes/kube-state-metrics) (KSM) is a simple service that listens to the Kubernetes API server and generates metrics about the state of the objects.

## 12-kubernetes-dashboards
This part isn't obligatory, but might be useful.

### 01-dashboard
[Kubernetes Dashboard](https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/)

I prefer to use [Lens](https://k8slens.dev/)

### 02-kiali
[Kiali](https://kiali.io/) - The Console for Istio Service Mesh. This app might help you to understand what is going on in your cluster. Or might not.

### Karpenter

***Important:*** Nodes for Karpenter should use *Cluster security group* 
> Cluster security group that was created by Amazon EKS for the cluster. Managed node groups use this security group for control-plane-to-data-plane communication. Referred to as 'Cluster security group' in the EKS console

This is [`cluster_primary_security_group_id`](https://github.com/terraform-aws-modules/terraform-aws-eks) Cluster security group that was created by Amazon EKS for the cluster. Managed node groups use this security group for control-plane-to-data-plane communication. Referred to as 'Cluster security group' in the EKS console

We need to create one ASG with a minimum of one node to launch CoreDNS and Karpenter. The next nodes will be managed by [Karpenter](https://karpenter.sh/)

In the Karpenter we use `taints` this allows us to separate applications by nodes. 

```yaml
  spec:
    taints:
      - key: "${local.tolerations_key}"
        value: "${local.tolerations_value}"
        effect: NoSchedule
```

For example, Istio might need a powerful CPU, and Victoriametrics needs more RAM. WordPress may need a lot of RAM and CPU. If WordPress or Magento pods and Istio pods are on the same nodes, this may lead to down service under high load. When these pods are divided by instances, that makes the service more resistant for high load traffic.
