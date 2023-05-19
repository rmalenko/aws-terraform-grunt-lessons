# [Шпаргалка по kubectl](https://kubernetes.io/ru/docs/reference/kubectl/cheatsheet/)

```bash
kubectl logs deployment/<name-of-deployment> # logs of deployment
kubectl logs -f deployment/<name-of-deployment> # follow logs
```

```bash
kubectl logs my-pod
```

```bash
kubectl get deployment -n kube-system
```

```bash
kubectl logs -f deployment/<name-of-deployment>
```

```bash
kubectl describe deploy <name-of-deployment>
```

```bash
kubectl get events [--namespace=default]
```

```shell
kubectl delete deployments/my-nginx services/my-nginx-svc

kubectl delete deployments/kubernetes-dashboard -n kubernetes-dashboard
```

### Getting a shell to a container
List pods:
```shell
kubectl get pod -n victoriametrics
```

Verify that the container is running:
```shell
kubectl get pod shell-demo
```

Get a shell to the running container:

```shell
kubectl -n victoriametrics exec --stdin --tty victoriametrics-f8b784b6d-gd62v -- /bin/ash

```

Listing enabled addons

```
eksctl get addons --cluster <cluster-name>
```

You can discover what addons are available to install on your cluster by running:

```
eksctl utils describe-addon-versions --cluster <cluster-name>
```

This will discover your cluster's kubernetes version and filter on that. Alternatively if you want to see what addons are available for a particular kubernetes version you can run:

```
eksctl utils describe-addon-versions --kubernetes-version <version>
```

## [Monitoring, Logging, and Debugging](https://kubernetes.io/docs/tasks/debug-application-cluster/)

### Debugging via a shell on the node
```shell
kubectl debug node/mynode -it --image=ubuntu
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