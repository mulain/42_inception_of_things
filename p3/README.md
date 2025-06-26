# Access the App managed by Argo CD

Check the status of the application and retrieve the service IP:

```BASH
kubectl -n dev get svc,pods -o wide
```
Example Output:
```
NAME                     TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)          AGE   SELECTOR
service/wil-playground   LoadBalancer   10.43.103.73   172.18.0.2    8888:32506/TCP   79s   app=wil-playground
```

This shows where the loadbalancer (the ingress controller) is exposing the app in the machine running k3d. It's running on port 8888 due to the configuration in confs/service.yaml.

So it's possible to access the app both via

```
curl http://localhost:8888
```
and via (for the above output)

```
curl http://172.18.0.2:32506
```
<br>

# Access the Argo CD Web Interface

Visit: http://localhost:8080
It is being forwarded in the install.sh script. Important: it is being forwarded on all interfaces due to the ```--adress 0.0.0.0``` flag - otherwise it would not be forwarded through to the physical host machine.



## NodePort

NodePort is a Kubernetes Service type. It creates a static port on each worker node’s network interface that forwards traffic into the Service, exposing the Service on a specific port (e.g., 30080) on every node in the cluster.
External clients can access the app by hitting any node’s IP address at that port.

We use NodePort instead of Loadbalancer or an actual ingress solution here.
A real ingress should usually be preffered, i.e. nginx or traefik, but we wanted to try this out and also this never has to scale.

It’s a simple way to expose a Service outside the cluster without an external load balancer. Useful for development, testing, or bare-metal clusters without cloud load balancers.


## Our structure

here is the basic structure of the setup
```
Physical host runs all this (just 42 reasons, in real life not mandatory to run in a separate VM)

Host machine (VM)
└── Docker daemon
    └── k3d Kubernetes cluster
        ├── Kubernetes node container "server:0"  ← control plane + workload node
        ├── Kubernetes node container "agent:0"   ← worker node (optional)
        └── (other nodes, if any)
            └── Kubernetes system running inside each node container
                └── Pods (one or more)
                    └── Containers (your app, etc.)

```