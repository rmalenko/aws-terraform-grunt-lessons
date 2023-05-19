# https://github.com/jenkins-x/terraform-aws-eks-jx
# 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

locals {
  namespace                          = data.terraform_remote_state.argocd_namespace.outputs.argocd_namespace
  cluster_certificate_authority_data = data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data
  cluster_name                       = data.terraform_remote_state.eks.outputs.cluster_id
  cluster_endpoint                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_oidc_issuer_url            = data.terraform_remote_state.eks.outputs.cluster_oidc_issuer_url
  oidc_arn                           = data.terraform_remote_state.eks.outputs.oidc_provider_arn
  kubernetes_storage_class_name      = data.terraform_remote_state.efs_csi_driver.outputs.kubernetes_storage_class
  size_of_persistent_volume_claim    = "50Gi"
  name_persistent_volume_claim       = "tekton"
  eks_iput_target                    = data.terraform_remote_state.efs-nfs.outputs.dns_of_efs_mount_target
  tolerations_key                    = "purpose"
  tolerations_value                  = "ci-cd"
  aws_template_name_karpenter        = data.terraform_remote_state.karpenter_and_launch_template.outputs.aws_template_name_karpenter

  tekton_operator_version = "0.59.0"

}

data "aws_eks_cluster_auth" "default" {
  name = local.cluster_name
}

provider "kubernetes" {
  config_path            = "~/.kube/kubeconfig-dev"
  host                   = local.cluster_endpoint
  cluster_ca_certificate = base64decode(local.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.default.token
}

provider "kubectl" {
  host                   = local.cluster_endpoint
  cluster_ca_certificate = base64decode(local.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.default.token
  load_config_file       = false
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/kubeconfig-dev"
  }
}

# # https://github.com/tektoncd/operator/releases
# resource "null_resource" "helm_repo_tecton" {
#   provisioner "local-exec" {
#     command = <<EOF
#     set -xe
#     cd ${path.root}
#     # rm ./release.yaml ./${local.tekton_operator_version}-tekton-operator-release.yaml || true
#     https://storage.googleapis.com/tekton-releases/operator/previous/${local.tekton_operator_version}/release.yaml
#     mv ./release.yaml ./${local.tekton_operator_version}-tekton-operator-release.yaml || true
#     EOF
#   }

#   triggers = {
#     build_number = local.tekton_operator_version
#   }
# }

resource "kubectl_manifest" "tekton-operator" {
  yaml_body = <<-YAML
  apiVersion: v1
  kind: Namespace
  metadata:
    name: tekton-operator
  ---
  apiVersion: apiextensions.k8s.io/v1
  kind: CustomResourceDefinition
  metadata:
    labels:
      operator.tekton.dev/release: v0.59.0
      version: v0.59.0
    name: tektonchains.operator.tekton.dev
  spec:
    group: operator.tekton.dev
    names:
      kind: TektonChain
      listKind: TektonChainList
      plural: tektonchains
      singular: tektonchain
    preserveUnknownFields: false
    scope: Cluster
    versions:
      - additionalPrinterColumns:
          - jsonPath: .status.version
            name: Version
            type: string
          - jsonPath: .status.conditions[?(@.type=="Ready")].status
            name: Ready
            type: string
          - jsonPath: .status.conditions[?(@.type=="Ready")].reason
            name: Reason
            type: string
        name: v1alpha1
        schema:
          openAPIV3Schema:
            description: Schema for the TektonChains API
            type: object
            x-kubernetes-preserve-unknown-fields: true
        served: true
        storage: true
        subresources:
          status: {}
  ---
  apiVersion: apiextensions.k8s.io/v1
  kind: CustomResourceDefinition
  metadata:
    labels:
      operator.tekton.dev/release: v0.59.0
      version: v0.59.0
    name: tektonconfigs.operator.tekton.dev
  spec:
    group: operator.tekton.dev
    names:
      kind: TektonConfig
      listKind: TektonConfigList
      plural: tektonconfigs
      singular: tektonconfig
    preserveUnknownFields: false
    scope: Cluster
    versions:
      - additionalPrinterColumns:
          - jsonPath: .status.version
            name: Version
            type: string
          - jsonPath: .status.conditions[?(@.type=="Ready")].status
            name: Ready
            type: string
          - jsonPath: .status.conditions[?(@.type=="Ready")].reason
            name: Reason
            type: string
        name: v1alpha1
        schema:
          openAPIV3Schema:
            description: Schema for the tektonconfigs API
            type: object
            x-kubernetes-preserve-unknown-fields: true
        served: true
        storage: true
        subresources:
          status: {}
  ---
  apiVersion: apiextensions.k8s.io/v1
  kind: CustomResourceDefinition
  metadata:
    labels:
      operator.tekton.dev/release: v0.59.0
      version: v0.59.0
    name: tektondashboards.operator.tekton.dev
  spec:
    group: operator.tekton.dev
    names:
      kind: TektonDashboard
      listKind: TektonDashboardList
      plural: tektondashboards
      singular: tektondashboard
    preserveUnknownFields: false
    scope: Cluster
    versions:
      - additionalPrinterColumns:
          - jsonPath: .status.version
            name: Version
            type: string
          - jsonPath: .status.conditions[?(@.type=="Ready")].status
            name: Ready
            type: string
          - jsonPath: .status.conditions[?(@.type=="Ready")].reason
            name: Reason
            type: string
        name: v1alpha1
        schema:
          openAPIV3Schema:
            description: Schema for the tektondashboards API
            type: object
            x-kubernetes-preserve-unknown-fields: true
        served: true
        storage: true
        subresources:
          status: {}
  ---
  apiVersion: apiextensions.k8s.io/v1
  kind: CustomResourceDefinition
  metadata:
    labels:
      operator.tekton.dev/release: v0.59.0
      version: v0.59.0
    name: tektonhubs.operator.tekton.dev
  spec:
    group: operator.tekton.dev
    names:
      kind: TektonHub
      listKind: TektonHubList
      plural: tektonhubs
      singular: tektonhub
    preserveUnknownFields: false
    scope: Cluster
    versions:
      - additionalPrinterColumns:
          - jsonPath: .status.version
            name: Version
            type: string
          - jsonPath: .status.conditions[?(@.type=="Ready")].status
            name: Ready
            type: string
          - jsonPath: .status.conditions[?(@.type=="Ready")].reason
            name: Reason
            type: string
          - jsonPath: .status.apiUrl
            name: ApiUrl
            type: string
          - jsonPath: .status.uiUrl
            name: UiUrl
            type: string
        name: v1alpha1
        schema:
          openAPIV3Schema:
            description: Schema for the tektonhubs API
            type: object
            x-kubernetes-preserve-unknown-fields: true
        served: true
        storage: true
        subresources:
          status: {}
  ---
  apiVersion: apiextensions.k8s.io/v1
  kind: CustomResourceDefinition
  metadata:
    labels:
      operator.tekton.dev/release: v0.59.0
      version: v0.59.0
    name: tektoninstallersets.operator.tekton.dev
  spec:
    group: operator.tekton.dev
    names:
      kind: TektonInstallerSet
      listKind: TektonInstallerSetList
      plural: tektoninstallersets
      singular: tektoninstallerset
    preserveUnknownFields: false
    scope: Cluster
    versions:
      - additionalPrinterColumns:
          - jsonPath: .status.conditions[?(@.type=="Ready")].status
            name: Ready
            type: string
          - jsonPath: .status.conditions[?(@.type=="Ready")].reason
            name: Reason
            type: string
        name: v1alpha1
        schema:
          openAPIV3Schema:
            description: Schema for the tektoninstallerset API
            type: object
            x-kubernetes-preserve-unknown-fields: true
        served: true
        storage: true
        subresources:
          status: {}
  ---
  apiVersion: apiextensions.k8s.io/v1
  kind: CustomResourceDefinition
  metadata:
    labels:
      operator.tekton.dev/release: v0.59.0
      version: v0.59.0
    name: tektonpipelines.operator.tekton.dev
  spec:
    group: operator.tekton.dev
    names:
      kind: TektonPipeline
      listKind: TektonPipelineList
      plural: tektonpipelines
      singular: tektonpipeline
    preserveUnknownFields: false
    scope: Cluster
    versions:
      - additionalPrinterColumns:
          - jsonPath: .status.version
            name: Version
            type: string
          - jsonPath: .status.conditions[?(@.type=="Ready")].status
            name: Ready
            type: string
          - jsonPath: .status.conditions[?(@.type=="Ready")].reason
            name: Reason
            type: string
        name: v1alpha1
        schema:
          openAPIV3Schema:
            description: Schema for the tektonpipelines API
            type: object
            x-kubernetes-preserve-unknown-fields: true
        served: true
        storage: true
        subresources:
          status: {}
  ---
  apiVersion: apiextensions.k8s.io/v1
  kind: CustomResourceDefinition
  metadata:
    labels:
      operator.tekton.dev/release: v0.59.0
      version: v0.59.0
    name: tektonresults.operator.tekton.dev
  spec:
    group: operator.tekton.dev
    names:
      kind: TektonResult
      listKind: TektonResultList
      plural: tektonresults
      singular: tektonresult
    preserveUnknownFields: false
    scope: Cluster
    versions:
      - additionalPrinterColumns:
          - jsonPath: .status.version
            name: Version
            type: string
          - jsonPath: .status.conditions[?(@.type=="Ready")].status
            name: Ready
            type: string
          - jsonPath: .status.conditions[?(@.type=="Ready")].reason
            name: Reason
            type: string
        name: v1alpha1
        schema:
          openAPIV3Schema:
            description: Schema for the tektonresults API
            properties:
              apiVersion:
                description: 'APIVersion defines the versioned schema of this representation of an object. Servers should convert recognized schemas to the latest internal value, and may reject unrecognized values. More info: https://git.k8s.io/community/contributors/devel/  api-conventions.md#resources'
                type: string
              kind:
                description: 'Kind is a string value representing the REST resource this object represents. Servers may infer this from the endpoint the client submits requests to. Cannot be updated. In CamelCase. More info: https://git.k8s.io/community/contributors/devel/api-conventions.md#types-kinds'
                type: string
              metadata:
                type: object
              spec:
                description: Spec defines the desired state of TektonResult
                properties:
                  targetNamespace:
                    description: namespace where tekton results will be installed
                    type: string
                type: object
              status:
                description: Status defines the observed state of TektonResult
                properties:
                  conditions:
                    description: The latest available observations of a resource's current state.
                    items:
                      properties:
                        lastTransitionTime:
                          description: LastTransitionTime is the last time the condition transitioned from one status to another. We use VolatileTime in place of metav1.Time to exclude this from creating equality.Semantic differences (all other things held constant).
                          type: string
                        message:
                          description: A human readable message indicating details about the transition.
                          type: string
                        reason:
                          description: The reason for the condition's last transition.
                          type: string
                        severity:
                          description: Severity with which to treat failures of this type of condition. When this is not specified, it defaults to Error.
                          type: string
                        status:
                          description: Status of the condition, one of True, False, Unknown.
                          type: string
                        type:
                          description: Type of condition.
                          type: string
                      required:
                        - type
                        - status
                      type: object
                    type: array
                  manifests:
                    description: The list of results manifests, which have been installed by the operator
                    items:
                      type: string
                    type: array
                  observedGeneration:
                    description: The generation last processed by the controller
                    type: integer
                  version:
                    description: The version of the installed release
                    type: string
                type: object
            type: object
        served: true
        storage: true
        subresources:
          status: {}
  ---
  apiVersion: apiextensions.k8s.io/v1
  kind: CustomResourceDefinition
  metadata:
    labels:
      operator.tekton.dev/release: v0.59.0
      version: v0.59.0
    name: tektontriggers.operator.tekton.dev
  spec:
    group: operator.tekton.dev
    names:
      kind: TektonTrigger
      listKind: TektonTriggerList
      plural: tektontriggers
      singular: tektontrigger
    preserveUnknownFields: false
    scope: Cluster
    versions:
      - additionalPrinterColumns:
          - jsonPath: .status.version
            name: Version
            type: string
          - jsonPath: .status.conditions[?(@.type=="Ready")].status
            name: Ready
            type: string
          - jsonPath: .status.conditions[?(@.type=="Ready")].reason
            name: Reason
            type: string
        name: v1alpha1
        schema:
          openAPIV3Schema:
            description: Schema for the tektontriggers API
            type: object
            x-kubernetes-preserve-unknown-fields: true
        served: true
        storage: true
        subresources:
          status: {}
  ---
  apiVersion: v1
  kind: ServiceAccount
  metadata:
    name: tekton-operator
    namespace: tekton-operator
  ---
  apiVersion: rbac.authorization.k8s.io/v1
  kind: Role
  metadata:
    labels:
      app.kubernetes.io/instance: default
    name: tekton-operator-info
    namespace: tekton-operator
  rules:
    - apiGroups:
        - ""
      resourceNames:
        - tekton-operator-info
      resources:
        - configmaps
      verbs:
        - get
  ---
  apiVersion: rbac.authorization.k8s.io/v1
  kind: ClusterRole
  metadata:
    name: tekton-config-read-role
  rules:
    - apiGroups:
        - operator.tekton.dev
      resources:
        - tektonconfigs
      verbs:
        - get
        - watch
        - list
  ---
  apiVersion: rbac.authorization.k8s.io/v1
  kind: ClusterRole
  metadata:
    name: tekton-operator
  rules:
    - apiGroups:
        - ""
      resources:
        - pods
        - services
        - endpoints
        - persistentvolumeclaims
        - events
        - configmaps
        - secrets
        - pods/log
        - limitranges
      verbs:
        - delete
        - deletecollection
        - create
        - patch
        - get
        - list
        - update
        - watch
    - apiGroups:
        - extensions
        - apps
        - networking.k8s.io
      resources:
        - ingresses
        - ingresses/status
      verbs:
        - delete
        - create
        - patch
        - get
        - list
        - update
        - watch
    - apiGroups:
        - ""
      resources:
        - namespaces
      verbs:
        - get
        - list
        - create
        - update
        - delete
        - patch
        - watch
    - apiGroups:
        - ""
      resources:
        - namespaces/finalizers
      verbs:
        - update
    - apiGroups:
        - apps
      resources:
        - deployments
        - daemonsets
        - replicasets
        - statefulsets
        - deployments/finalizers
      verbs:
        - get
        - list
        - create
        - update
        - delete
        - deletecollection
        - patch
        - watch
    - apiGroups:
        - monitoring.coreos.com
      resources:
        - servicemonitors
      verbs:
        - get
        - create
        - delete
    - apiGroups:
        - rbac.authorization.k8s.io
      resources:
        - clusterroles
        - roles
      verbs:
        - get
        - create
        - update
        - delete
    - apiGroups:
        - ""
      resources:
        - serviceaccounts
      verbs:
        - get
        - list
        - create
        - update
        - delete
        - patch
        - watch
        - impersonate
    - apiGroups:
        - rbac.authorization.k8s.io
      resources:
        - clusterrolebindings
        - rolebindings
      verbs:
        - get
        - create
        - update
        - delete
    - apiGroups:
        - apiextensions.k8s.io
      resources:
        - customresourcedefinitions
        - customresourcedefinitions/status
      verbs:
        - get
        - create
        - update
        - delete
        - list
        - patch
        - watch
    - apiGroups:
        - admissionregistration.k8s.io
      resources:
        - mutatingwebhookconfigurations
        - validatingwebhookconfigurations
      verbs:
        - get
        - list
        - create
        - update
        - delete
        - patch
        - watch
    - apiGroups:
        - build.knative.dev
      resources:
        - builds
        - buildtemplates
        - clusterbuildtemplates
      verbs:
        - get
        - list
        - create
        - update
        - delete
        - patch
        - watch
    - apiGroups:
        - extensions
      resources:
        - deployments
      verbs:
        - get
        - list
        - create
        - update
        - delete
        - patch
        - watch
    - apiGroups:
        - extensions
      resources:
        - deployments/finalizers
      verbs:
        - get
        - list
        - create
        - update
        - delete
        - patch
        - watch
    - apiGroups:
        - policy
      resources:
        - podsecuritypolicies
      verbs:
        - get
        - create
        - update
        - delete
        - use
    - apiGroups:
        - operator.tekton.dev
      resources:
        - '*'
        - tektonaddons
      verbs:
        - get
        - list
        - create
        - update
        - delete
        - deletecollection
        - patch
        - watch
    - apiGroups:
        - tekton.dev
      resources:
        - tasks
        - clustertasks
        - taskruns
        - pipelines
        - pipelineruns
        - pipelineresources
        - conditions
        - tasks/status
        - clustertasks/status
        - taskruns/status
        - pipelines/status
        - pipelineruns/status
        - pipelineresources/status
        - taskruns/finalizers
        - pipelineruns/finalizers
        - runs
        - runs/status
        - runs/finalizers
      verbs:
        - get
        - list
        - create
        - update
        - delete
        - deletecollection
        - patch
        - watch
    - apiGroups:
        - triggers.tekton.dev
        - operator.tekton.dev
      resources:
        - '*'
      verbs:
        - add
        - get
        - list
        - create
        - update
        - delete
        - deletecollection
        - patch
        - watch
    - apiGroups:
        - dashboard.tekton.dev
      resources:
        - '*'
        - tektonaddons
        - extensions
      verbs:
        - get
        - list
        - create
        - update
        - delete
        - deletecollection
        - patch
        - watch
    - apiGroups:
        - security.openshift.io
      resources:
        - securitycontextconstraints
      verbs:
        - use
    - apiGroups:
        - coordination.k8s.io
      resources:
        - leases
      verbs:
        - get
        - list
        - create
        - update
        - delete
        - patch
        - watch
    - apiGroups:
        - autoscaling
      resources:
        - horizontalpodautoscalers
      verbs:
        - delete
        - deletecollection
        - create
        - patch
        - get
        - list
        - update
        - watch
    - apiGroups:
        - policy
      resources:
        - poddisruptionbudgets
      verbs:
        - delete
        - deletecollection
        - create
        - patch
        - get
        - list
        - update
        - watch
    - apiGroups:
        - serving.knative.dev
      resources:
        - '*'
        - '*/status'
        - '*/finalizers'
      verbs:
        - get
        - list
        - create
        - update
        - delete
        - deletecollection
        - patch
        - watch
    - apiGroups:
        - batch
      resources:
        - cronjobs
        - jobs
      verbs:
        - delete
        - create
        - patch
        - get
        - list
        - update
        - watch
    - apiGroups:
        - admissionregistration.k8s.io
      resources:
        - mutatingwebhookconfigurations
        - validatingwebhookconfigurations
      verbs:
        - delete
        - create
        - patch
        - get
        - list
        - update
        - watch
    - apiGroups:
        - authentication.k8s.io
      resources:
        - tokenreviews
      verbs:
        - create
    - apiGroups:
        - authorization.k8s.io
      resources:
        - subjectaccessreviews
      verbs:
        - create
    - apiGroups:
        - results.tekton.dev
      resources:
        - '*'
      verbs:
        - delete
        - deletecollection
        - create
        - patch
        - get
        - list
        - update
        - watch
    - apiGroups:
        - resolution.tekton.dev
      resources:
        - resolutionrequests
      verbs:
        - get
        - list
        - watch
        - create
        - delete
  ---
  apiVersion: rbac.authorization.k8s.io/v1
  kind: RoleBinding
  metadata:
    labels:
      app.kubernetes.io/instance: default
    name: tekton-operator-info
    namespace: tekton-operator
  roleRef:
    apiGroup: rbac.authorization.k8s.io
    kind: Role
    name: tekton-operator-info
  subjects:
    - apiGroup: rbac.authorization.k8s.io
      kind: Group
      name: system:authenticated
  ---
  apiVersion: rbac.authorization.k8s.io/v1
  kind: ClusterRoleBinding
  metadata:
    name: tekton-config-read-rolebinding
  roleRef:
    apiGroup: rbac.authorization.k8s.io
    kind: ClusterRole
    name: tekton-config-read-role
  subjects:
    - apiGroup: rbac.authorization.k8s.io
      kind: Group
      name: system:authenticated
  ---
  apiVersion: rbac.authorization.k8s.io/v1
  kind: ClusterRoleBinding
  metadata:
    name: tekton-operator
  roleRef:
    apiGroup: rbac.authorization.k8s.io
    kind: ClusterRole
    name: tekton-operator
  subjects:
    - kind: ServiceAccount
      name: tekton-operator
      namespace: tekton-operator
  ---
  apiVersion: v1
  data:
    _example: |
      ################################
      #                              #
      #    EXAMPLE CONFIGURATION     #
      #                              #
      ################################

      # This block is not actually functional configuration,
      # but serves to illustrate the available configuration
      # options and document them in a way that is accessible
      # to users that `kubectl edit` this config map.
      #
      # These sample configuration options may be copied out of
      # this example block and unindented to be in the data block
      # to actually change the configuration.

      # Common configuration for all Knative codebase
      zap-logger-config: |
        {
          "level": "info",
          "development": false,
          "outputPaths": ["stdout"],
          "errorOutputPaths": ["stderr"],
          "encoding": "json",
          "encoderConfig": {
            "timeKey": "ts",
            "levelKey": "level",
            "nameKey": "logger",
            "callerKey": "caller",
            "messageKey": "msg",
            "stacktraceKey": "stacktrace",
            "lineEnding": "",
            "levelEncoder": "",
            "timeEncoder": "iso8601",
            "durationEncoder": "",
            "callerEncoder": ""
          }
        }
    loglevel.controller: info
    loglevel.webhook: info
    zap-logger-config: |
      {
        "level": "debug",
        "development": true,
        "sampling": {
          "initial": 100,
          "thereafter": 100
        },
        "outputPaths": ["stdout"],
        "errorOutputPaths": ["stderr"],
        "encoding": "json",
        "encoderConfig": {
          "timeKey": "",
          "levelKey": "level",
          "nameKey": "logger",
          "callerKey": "caller",
          "messageKey": "msg",
          "stacktraceKey": "stacktrace",
          "lineEnding": "",
          "levelEncoder": "",
          "timeEncoder": "",
          "durationEncoder": "",
          "callerEncoder": ""
        }
      }
  kind: ConfigMap
  metadata:
    labels:
      operator.tekton.dev/release: devel
    name: config-logging
    namespace: tekton-operator
  ---
  apiVersion: v1
  data:
    AUTOINSTALL_COMPONENTS: "true"
    DEFAULT_TARGET_NAMESPACE: tekton-pipelines
  kind: ConfigMap
  metadata:
    labels:
      operator.tekton.dev/release: devel
    name: tekton-config-defaults
    namespace: tekton-operator
  ---
  apiVersion: v1
  data:
    _example: |
      ################################
      #                              #
      #    EXAMPLE CONFIGURATION     #
      #                              #
      ################################
      # This block is not actually functional configuration,
      # but serves to illustrate the available configuration
      # options and document them in a way that is accessible
      # to users that `kubectl edit` this config map.
      #
      # These sample configuration options may be copied out of
      # this example block and unindented to be in the data block
      # to actually change the configuration.
      # metrics.backend-destination field specifies the system metrics destination.
      # It supports either prometheus (the default) or stackdriver.
      # Note: Using Stackdriver will incur additional charges.
      metrics.backend-destination: prometheus
      # metrics.stackdriver-project-id field specifies the Stackdriver project ID. This
      # field is optional. When running on GCE, application default credentials will be
      # used and metrics will be sent to the cluster's project if this field is
      # not provided.
      metrics.stackdriver-project-id: "<your stackdriver project id>"
      # metrics.allow-stackdriver-custom-metrics indicates whether it is allowed
      # to send metrics to Stackdriver using "global" resource type and custom
      # metric type. Setting this flag to "true" could cause extra Stackdriver
      # charge.  If metrics.backend-destination is not Stackdriver, this is
      # ignored.
      metrics.allow-stackdriver-custom-metrics: "false"
  kind: ConfigMap
  metadata:
    labels:
      app.kubernetes.io/instance: default
    name: tekton-config-observability
    namespace: tekton-operator
  ---
  apiVersion: v1
  data:
    version: v0.59.0
  kind: ConfigMap
  metadata:
    labels:
      app.kubernetes.io/instance: default
    name: tekton-operator-info
    namespace: tekton-operator
  ---
  apiVersion: v1
  kind: Secret
  metadata:
    labels:
      app: tekton-operator
      name: tekton-operator-webhook
    name: tekton-operator-webhook-certs
    namespace: tekton-operator
  ---
  apiVersion: v1
  kind: Service
  metadata:
    labels:
      app: tekton-pipelines-controller
      version: v0.59.0
    name: tekton-operator
    namespace: tekton-operator
  spec:
    ports:
      - name: http-metrics
        port: 9090
        protocol: TCP
        targetPort: 9090
    selector:
      app: tekton-operator
      name: tekton-operator
  ---
  apiVersion: v1
  kind: Service
  metadata:
    labels:
      app: tekton-operator
      name: tekton-operator-webhook
      operator.tekton.dev/release: v0.59.0
      version: v0.59.0
    name: tekton-operator-webhook
    namespace: tekton-operator
  spec:
    ports:
      - name: https-webhook
        port: 443
        targetPort: 8443
    selector:
      app: tekton-operator
      name: tekton-operator-webhook
  ---
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    labels:
      operator.tekton.dev/release: v0.59.0
      version: v0.59.0
    name: tekton-operator
    namespace: tekton-operator
  spec:
    replicas: 1
    selector:
      matchLabels:
        name: tekton-operator
    template:
      metadata:
        labels:
          app: tekton-operator
          name: tekton-operator
      spec:
        tolerations:
        - key: "${local.tolerations_key}"
          operator: "Equal"
          value: "${local.tolerations_value}"
          effect: "NoSchedule"
        containers:
          - env:
              - name: SYSTEM_NAMESPACE
                valueFrom:
                  fieldRef:
                    fieldPath: metadata.namespace
              - name: POD_NAME
                valueFrom:
                  fieldRef:
                    fieldPath: metadata.name
              - name: OPERATOR_NAME
                value: tekton-operator
              - name: IMAGE_PIPELINES_PROXY
                value: gcr.io/tekton-releases/github.com/tektoncd/operator/cmd/kubernetes/proxy-webhook:v0.59.0@sha256:c2c3a38c2d26fc05d336e0e47c24a488a26cc6df8d72cd55e00ac05668d090d4
              - name: IMAGE_JOB_PRUNER_TKN
                value: gcr.io/tekton-releases/dogfooding/tkn@sha256:025de221fb059ca24a3b2d988889ea34bce48dc76c0cf0d6b4499edb8c21325f
              - name: METRICS_DOMAIN
                value: tekton.dev/operator
              - name: VERSION
                value: v0.59.0
              - name: CONFIG_OBSERVABILITY_NAME
                value: tekton-config-observability
              - name: AUTOINSTALL_COMPONENTS
                valueFrom:
                  configMapKeyRef:
                    key: AUTOINSTALL_COMPONENTS
                    name: tekton-config-defaults
              - name: DEFAULT_TARGET_NAMESPACE
                valueFrom:
                  configMapKeyRef:
                    key: DEFAULT_TARGET_NAMESPACE
                    name: tekton-config-defaults
            image: gcr.io/tekton-releases/github.com/tektoncd/operator/cmd/kubernetes/operator:v0.59.0@sha256:e5e6cbf5c56a3c62136ac71e478a26fa93067ced6334929f99a82cfd2d726674
            imagePullPolicy: Always
            name: tekton-operator
        serviceAccountName: tekton-operator
  ---
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    labels:
      operator.tekton.dev/release: v0.59.0
      version: v0.59.0
    name: tekton-operator-webhook
    namespace: tekton-operator
  spec:
    replicas: 1
    selector:
      matchLabels:
        name: tekton-operator-webhook
    template:
      metadata:
        labels:
          app: tekton-operator
          name: tekton-operator-webhook
      spec:
        containers:
          - env:
              - name: SYSTEM_NAMESPACE
                valueFrom:
                  fieldRef:
                    fieldPath: metadata.namespace
              - name: CONFIG_LOGGING_NAME
                value: config-logging
              - name: WEBHOOK_SERVICE_NAME
                value: tekton-operator-webhook
              - name: WEBHOOK_SECRET_NAME
                value: tekton-operator-webhook-certs
              - name: METRICS_DOMAIN
                value: tekton.dev/operator
            image: gcr.io/tekton-releases/github.com/tektoncd/operator/cmd/kubernetes/webhook:v0.59.0@sha256:24b94e84b9edecd6f98581f4921832a2a1deae13ed9b2308f985eb86f29149b8
            name: tekton-operator-webhook
            ports:
              - containerPort: 8443
                name: https-webhook
        tolerations:
        - key: "${local.tolerations_key}"
          operator: "Equal"
          value: "${local.tolerations_value}"
          effect: "NoSchedule"
        serviceAccountName: tekton-operator
  ---
  YAML
}