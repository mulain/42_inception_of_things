# 🌐 K3s Ingress

Part 2 sets up a single-node K3s cluster using Vagrant and demonstrates the use of **Ingress** with multiple lightweight web apps. We used **Traefik**, which comes bundled with K3s, as the default Ingress controller.

### What is an Ingress?

An Ingress is a Kubernetes API object that defines rules for routing external HTTP(S) traffic to internal Services based on hostnames or paths.

### What is the Ingress Controller?

It's a Kubernetes component that manages external access to services inside a cluster, typically HTTP and HTTPS traffic.

It consists of a pod (or set of pods) running inside the cluster that configures a load balancer or proxy (like NGINX, Traefik, or HAProxy) based on Ingress rules.

It acts like a smart router or reverse proxy inside the cluster.

#### Popular Ingress Controllers
- NGINX Ingress Controller (very common and widely used)

- Traefik (modern, supports dynamic configuration)


## 📦 Requirements

- [VirtualBox](https://www.virtualbox.org/)
- [Vagrant](https://www.vagrantup.com/)


## ⚙️ Install Script

- `Traefik` is installed by default and serves as the built-in Ingress controller. So no extra setting necessary in the scipt.

- `--node-ip=192.168.56.110` Sets the external IP address the node should advertise. This is the IP other nodes or users will use to reach it.

- `--flannel-iface=enp0s8` Tells Flannel (the CNI plugin) to use enp0s8 as the network interface for pod-to-pod traffic. Important in Vagrant setups where the private network is usually on a secondary interface like eth1 or enp0s8.

- `--write-kubeconfig-mode 644` Sets the file permission of `/etc/rancher/k3s/k3s.yaml` so it's world-readable. This allows non-root users or shared tooling to access the Kubernetes config file.

- `export KUBECONFIG=/etc/rancher/k3s/k3s.yaml` By default, `K3s` writes the kubeconfig file (credentials, cluster IP, CA, etc.) to the path referenced in the command. However, `kubectl` looks for the config file in `~/.kube/config`. By setting `KUBECONFIG` env variable, we are overriding `kubectl`'s standard behavior.


## 🛠️ Kubernetes Deployments

A Kubernetes Deployment manages the lifecycle of a set of Pods, ensuring the desired number of replicas are running and up to date. It automatically handles rolling updates, restarts failed Pods, and maintains high availability. By defining a Deployment, we declare how the application should run, and Kubernetes ensures it stays that way.

-  `apiVersion: apps/v1`
    - Specifies the Kubernetes API version to use for the object.
    - `apps/v1` is the stable version for Deployments in modern clusters.
- `kind: Deployment`
    - Declares the type of Kubernetes resource being defined.
    - A Deployment ensures a desired number of Pods are running at all times. It supports rolling updates, rollbacks, and self-healing.
- `metadata`
    - Metadata about the resource.
    - `name: appX` is the name of the Deployment. It will appear in `kubectl get deployments`
- `spec`
    - Defines the desired state of the Deployment
    - `replicas` Number of Pods running, can be scaled up to run more identical Pods.
    - `selector` Tells the Deployment which Pods it should manage.
        - we use the simple `matchLabels` selector:
        ```
        selector:
            matchLabels:
                app: appX
         ```

        which will select any Pods with:
        ```
        labels:
            app: appX
        ```
    - `template` The blueprint for the Pods that the Deployment should create and manage.
        - `spec` Another spec layer, this time to define the actual container(s) inside the Pod.
            - `containers`
                - `name: app3` Gives a name to the container (used for logs, monitoring, etc.)
                - `image: hashicorp/http-echo` Tells Kubernetes to pull and run this Docker image. http-echo is a simple server that responds with a fixed string.
                - `args` These are command-line arguments passed to the container on start.
                - `ports`
                    - `containerPort: 5678` Declares that the container listens on port 5678 internally. This doesn't expose it outside the cluster — it’s mostly informational for Kubernetes, but also used by Services.


## 🔗 Kubernetes Services

A Kubernetes Service is an abstraction that exposes a group of Pods under a stable network endpoint. It automatically load-balances traffic to the matching Pods using label selectors, even as Pods are created or destroyed. This allows other services or external clients to access the app reliably without needing to know individual Pod IPs.

- `apiVersion: v1`
Specifies the Kubernetes API version for this resource. v1 is the core API version where Service lives.

- `kind: Service` Defines this resource as a Service, which exposes one or more Pods to network access. It provides stable IP and DNS for those Pods.


- `metadata` Metadata about the Service.
    - `name: app3` The name of this Service object. This name is how you refer to the Service inside the cluster (e.g., DNS: app3.default.svc.cluster.local).

- `spec` Desired behavior of the Service.
    - `selector`
        - `app: app3` This selects the set of Pods this Service targets. It matches Pods with the label app: app3 (e.g., our Deployment's Pods).Only Pods matching this selector will receive traffic sent to this Service.

- `ports` A list of ports that the Service exposes.
    - `port: 80` The port on the Service itself (the port clients connect to).
    - `targetPort: 5678` The port on the Pod's container that the traffic will be forwarded to.

This Service listens on port 80 and forwards requests to port 5678 on the matching Pods.

### 🧩 What happens overall?

A client inside the cluster can connect to app3 on port 80.  
The Service forwards that traffic to port 5678 on the Pods labeled app: app3.  
The Deployment's containerPort must match the Service's targetPort.  
This abstracts away Pod IPs and allows Pods to scale dynamically.


### ⁉️ What name or label has to match between service.yaml, deployment.yaml and ingress.yaml?

The conf files of app1 show what has to match. If it doesn't match there, it doesn't have to. If it does match, it must. Compare service, deployment and ingress!

## 🚀 Getting Started

To start the cluster and deploy the apps:

```bash
vagrant up
```

This will:

1. Create a VM called `wmardinS`

1. Install `K3s` with `Traefik` and `Flannel` (using the correct interface)

1. Apply all files in `./confs`
    - App deployments and services
    - Ingress configuration


## 📡 Accessing the Apps

Once everything is up, you can access the apps using curl with custom Host headers:

`curl -H "Host: app1.com" http://192.168.56.110` -> Hello from app1

`curl -H "Host: app2.com" http://192.168.56.110` -> Hello from app2

`curl -H "Host: shmismshmang.com" http://192.168.56.110` -> Hello from app3


## 💡 How It Works
- The VM uses IP 192.168.56.110 via a private network interface (enp0s8)

- Each app (app1, app2, app3) runs a small container using hashicorp/http-echo

- The Ingress is handled by Traefik, which routes based on the Host header


## 📌 Useful Commands

Overview of deployed apps and replica counts:

```
kubectl -n dev get deployments
```

Pod overview with details:
```
kubectl -n dev get pods -o wide
```

Detailed view of all:
```
kubectl -n dev get all
```