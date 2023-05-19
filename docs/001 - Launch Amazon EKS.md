# Fargate
## Caveats - Amazon EKS Fargate Pods:

- [Only support Application Load Balancers (Classic Load Balancers and Network Load Balancers are not supported).](https://docs.aws.amazon.com/eks/latest/userguide/load-balancing.html)
- Are [limited to a maximum of 4 vCPU and 30GB of memory.](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-cpu-memory-error.html)
- Currently [don’t support stateful workloads that require persistent volumes or file systems.](https://docs.aws.amazon.com/eks/latest/userguide/fargate.html)
- [Cannot run DaemonSets (instead, you’ll need to reconfigure a daemon to run as a sidecar container in your Pods).](https://docs.aws.amazon.com/eks/latest/userguide/fargate.html)

EKS creates by Terraform module [terraform-aws-eks](https://github.com/terraform-aws-modules/terraform-aws-eks)

## [Install kubectl в Linux](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)
```
curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl
```

```
chmod +x ./kubectl
```

```
mv ./kubectl /usr/local/bin/kubectl
```

## Get access to cluster
1. create file in `touch /home/$USER/.kube/kubeconfig-dev` 
2. add to `/home/$USER/.bashrc` `export KUBECONFIG=~/.kube/kubeconfig-dev`
3. run `source ~/.bashrc` or `. ~/.bashrc`
4. run `aws eks --profile userprofilename --region us-east-1 update-kubeconfig --name monitoring-eks-seasnail`

***Important:*** Of course, you are already have configured your AWS profile. If you didn't, do this before running step **4**. Follow this document [Named profiles](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html)

Check if you have able get access.
`kubectl get pods --all-namespaces -o wide`

you should see something like this

```
NAMESPACE     NAME                       READY   STATUS    RESTARTS   AGE
kube-system   coredns-66cb55d4f4-9k8c5   0/1     Pending   0          44m
kube-system   coredns-66cb55d4f4-ztr2l   0/1     Pending   0          44m
```

If you have seen outputs, you need to run this to get core-DNS working

```
kubectl patch deployment coredns -n kube-system --type json -p='[{"op": "remove", "path": "/spec/template/metadata/annotations/eks.amazonaws.com~1compute-type"}]'
```

Docs [(Optional) Update CoreDNS](https://docs.aws.amazon.com/eks/latest/userguide/fargate-getting-started.html)

Then needs to restart rollout of coredns

`kubectl rollout restart -n kube-system deployment coredns`

After a few minutes, coredns changed their status to READY. Check it  by running:

`kubectl get pods --all-namespaces -o wide`

```
NAMESPACE     NAME                       READY   STATUS    RESTARTS   AGE
kube-system   coredns-6df59bc754-4vgdg   1/1     Running   0          2m48s
kube-system   coredns-6df59bc754-dnprr   1/1     Running   0          2m48s
```

## Creating a new namespace

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: <insert-namespace-name-here>
```

### Delete namespace
```shell
kubectl get namespaces
```

#### Delete when a [Namespace "stuck" as Terminating](https://stackoverflow.com/questions/52369247/namespace-stuck-as-terminating-how-i-removed-it)
```shell
$(
NAMESPACE=istio-system
kubectl proxy &
kubectl get namespace $NAMESPACE -o json |jq '.spec = {"finalizers":[]}' >temp.json
curl -k -H "Content-Type: application/json" -X PUT --data-binary @temp.json 127.0.0.1:8001/api/v1/namespaces/$NAMESPACE/finalize
)
```

#### Force delete a pod
```shell
kubectl delete pod victoria-metrics-cluster-vmstorage-0 -n victoriametrics --grace-period 0 --force
```

`kubectl delete ns developer`

Next step [[002 - Deploying the Dashboard UI]]
[[003 - Docker]]

[[Cheat_Sheet_kubectl]]
