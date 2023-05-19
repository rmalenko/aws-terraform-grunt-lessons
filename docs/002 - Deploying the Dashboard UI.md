# Deploying the Dashboard UI
[Official documentations](https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/)

Run: 
```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.3.1/aio/deploy/recommended.yaml
```

`kubectl get pods --all-namespaces`

```
NAMESPACE              NAME                                         READY   STATUS    RESTARTS   AGE
kube-system            coredns-6df59bc754-4vgdg                     1/1     Running   0          22m
kube-system            coredns-6df59bc754-dnprr                     1/1     Running   0          22m
kubernetes-dashboard   dashboard-metrics-scraper-856586f554-tfl8w   0/1     Pending   0          98s
kubernetes-dashboard   kubernetes-dashboard-67484c44f6-8jwvf        1/1     Running   0          98s
```

## [Command line proxy](https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/#command-line-proxy)

You can enable access to the Dashboard using the `kubectl` command-line tool, by running the following command:

```
kubectl proxy
```

Kubectl will make Dashboard available at [http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/](http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/).

You should see this

![[image20211020113029.png]]

To get access you need a token. 

Running this
`aws eks --profile userprofilename --cluster-name=monitoring-eks-seasnail get-token`
or 
`kubectl describe secret $(kubectl get secret | awk '/^admin-user-token-/{print $1}') | awk '$1=="token:"{print $2}'`

You should get something like this:

```
{"kind": "ExecCredential", "apiVersion": "client.authentication.k8s.io/v1alpha1", "spec": {}, "status": {"expirationTimestamp": "2021-10-20T08:46:23Z", "token": "k8s-aws-v1.aHR0cHM6Ly9lfgklfghvb,XdzLmNvbS8_QWN0aW9uPUdldENhbGxlcklkZW50aXR5JlZlcnNpb249MjAxMS0wNi0xNSZYLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFlgkoritltryjUlJITTM2QUZPQjU1JTJGMjAyMTEwMjAlMkZ1cy1lYXN0LTElMkZzdHMlMkZhd3M0X3JlcXVlc3QmWC1BbXotRGF0ZT0yMDIxMTAyMFQwODMyMjNaJlgtQW16LUV4cGlyZXM9NjAmWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0JTNCeC1rOHMtYXdzLWlkJlgtQW16LVNpZ25hdHVyZT01MDk0ZDgxZWQ1ZTQ0MTUyNTUzNjY4ODkzODA4Nzc4Y2ZmNDE3YjQzZGJjOTgyZmQzN2YxYWZlMTgwNTdjZDhj"}}

```

The string from `k8s-aws-` to end is your access token.

## [Installing the Kubernetes Metrics Server](https://docs.aws.amazon.com/eks/latest/userguide/metrics-server.html)

`kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml`

`kubectl get deployment metrics-server -n kube-system`