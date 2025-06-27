# ArgoCD GitOps with k3d

Part 3 demonstrates a **GitOps workflow** using ArgoCD for continuous deployment to a local Kubernetes cluster. This setup uses k3d (Kubernetes in Docker) instead of Vagrant VMs, providing a lightweight development environment.

## What is GitOps?

GitOps is a methodology where Git is the single source of truth for declarative infrastructure and applications. Changes to infrastructure or applications are made through Git commits, and an automated process ensures the actual state matches the desired state defined in Git.

## Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Git Repository│    │   ArgoCD        │    │   k3d Cluster   │
│   (GitHub)      │───▶│   Controller    │───▶│   (Local)       │
│                 │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Components

### k3d Cluster
- **Lightweight Kubernetes**: Runs inside Docker containers
- **Single-node setup**: Control plane and worker on same node
- **Port mapping**: Maps host ports to cluster services
- **Local development**: No VM overhead, faster startup

### ArgoCD
- **GitOps controller**: Monitors Git repository for changes
- **Automated sync**: Applies configuration changes automatically
- **Web interface**: Visual management of applications
- **CLI tools**: Command-line interface for operations

### Application
- **wil-playground**: Simple web application
- **Container image**: `wil42/playground:v1`  
we will be changing the tag `:v1` to demonstrate ArgoCD's functionality
- **NodePort service**: Exposed on port 30080
- **dev namespace**: Isolated application environment

## Installation Script (`install.sh`)

The installation script sets up the complete environment:

### 1. Prerequisites Installation
```bash
# Docker installation
curl -fsSL https://get.docker.com | bash
sudo usermod -aG docker $USER

# k3d installation  
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# kubectl installation
KUBECTL_VERSION=$(curl -sL https://dl.k8s.io/release/stable.txt)
curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
```

### 2. k3d Cluster Creation
```bash
k3d cluster create mycluster --api-port 6550 \
  -p "8888:30080@server:0" \
  -p "8889:30081@server:0"
```

**Port Mapping:**
- `8888:30080` - Maps host port 8888 to NodePort 30080
- `8889:30081` - Maps host port 8889 to NodePort 30081
- `6550` - Kubernetes API server port

### 3. ArgoCD Installation
```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Install ArgoCD CLI
VERSION=$(curl -s https://api.github.com/repos/argoproj/argo-cd/releases/latest | grep tag_name | cut -d '"' -f 4)
curl -sSL -o argocd "https://github.com/argoproj/argo-cd/releases/download/${VERSION}/argocd-linux-amd64"
```

### 4. Application Deployment
```bash
# Create dev namespace
kubectl create namespace dev

# Create ArgoCD application
argocd app create wil-playground \
  --repo https://github.com/karolinakwasny/Inception_of_things_npavelic.git \
  --path p3/confs \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace dev \
  --sync-policy automated
```

## Configuration Files

### Deployment (`confs/deployment.yaml`)
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wil-playground
  namespace: dev
spec:
  replicas: 1
  selector:
    matchLabels:
      app: wil-playground
  template:
    metadata:
      labels:
        app: wil-playground
    spec:
      containers:
        - name: app
          image: wil42/playground:v2
          ports:
            - containerPort: 8888
```

**Notes:**
- **Label selector**: `spec.template.metadata.labels` must match `spec.selector.matchLabels`. It's how the deployment knows which Pod to manage.
- **containerPort**: This field is for documentation and optional use by Kubernetes. It doesn’t affect what port the app actually listens on — that’s defined inside the container’s code. However, it's useful for:

    - Readability
    - Port-forwarding (kubectl port-forward defaults to this port)
    - Defining readiness/liveness probes

    It's good practice to set containerPort to match the app’s real internal port (in this case, 8888), especially when creating a Service with targetPort: 8888.

### Service (`confs/service.yaml`)
```yaml
apiVersion: v1
kind: Service
metadata:
  name: wil-playground
  namespace: dev
spec:
  type: NodePort
  selector:
    app: wil-playground
  ports:
    - port: 80
      targetPort: 8888
      nodePort: 30080
```

**Service Configuration:**
- **NodePort type**: Exposes service on cluster node ports
- **Port mapping**: 
  - `port: 80` - Service port. Used for communication inside the cluster.
  - `targetPort: 8888` - Port the Service forwards to on the Pod. So the app in the Pod should be listening on this.
  - `nodePort: 30080` - External access port.

## Access Points

### ArgoCD Web Interface
- **URL**: http://localhost:8080
- **Username**: `admin`
- **Password**: Retrieved from installation script
- **Features**: Application monitoring, sync status, logs

### Application Access
- **URL**: http://localhost:8888
- **Alternative**: http://localhost:8889 (backup port)
- **NodePort**: 30080 (direct cluster access)

## GitOps Workflow

1. **Configuration Changes**: Modify files in `p3/confs/`
2. **Git Commit**: Push changes to GitHub repository
3. **ArgoCD Detection**: ArgoCD detects repository changes
4. **Automatic Sync**: ArgoCD applies changes to cluster
5. **Application Update**: New version deployed automatically

## Useful Commands

### Check Application Status
```bash
kubectl -n dev get svc,pods -o wide
```

### ArgoCD Application Management
```bash
# List applications
argocd app list

# Get application status
argocd app get wil-playground

# Manual sync
argocd app sync wil-playground

# View logs
argocd app logs wil-playground
```

### Cluster Management
```bash
# Check cluster status
k3d cluster list

# Access cluster
kubectl cluster-info

# View all resources
kubectl get all -n dev
```

## Cleanup Script (`uninstall.sh`)

The cleanup script removes all components:

```bash
# Delete ArgoCD application
argocd app delete wil-playground --yes

# Delete namespaces
kubectl delete namespace dev --ignore-not-found
kubectl delete namespace argocd --ignore-not-found

# Delete k3d cluster
k3d cluster delete mycluster

# Remove ArgoCD CLI
rm -f /usr/local/bin/argocd
```

## Troubleshooting

### Port Forward Issues
If ArgoCD web interface is not accessible:
```bash
# Check if port forward is running
ps aux | grep port-forward

# Restart port forward
kubectl -n argocd port-forward svc/argocd-server 8080:443 --address 0.0.0.0
```

### Application Not Syncing
```bash
# Check ArgoCD application status
argocd app get wil-playground

# Force sync
argocd app sync wil-playground --force

# Check logs
argocd app logs wil-playground
```

### Cluster Issues
```bash
# Restart k3d cluster
k3d cluster stop mycluster
k3d cluster start mycluster

# Check cluster health
kubectl get nodes
kubectl get pods -n kube-system
```

## Advantages of This Setup

1. **Lightweight**: No VM overhead, faster startup
2. **GitOps**: Version-controlled deployments
3. **Automated**: Changes applied automatically
4. **Visual**: Web interface for monitoring
5. **Local**: Complete development environment
6. **Scalable**: Easy to extend with more applications

## Next Steps

This setup provides a foundation for:
- Adding more applications
- Implementing CI/CD pipelines
- Setting up monitoring and logging
- Scaling to multiple environments
- Integrating with external services

---

# Original Content

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

NodePort is a Kubernetes Service type. It creates a static port on each worker node's network interface that forwards traffic into the Service, exposing the Service on a specific port (e.g., 30080) on every node in the cluster.
External clients can access the app by hitting any node's IP address at that port.

We use NodePort instead of Loadbalancer or an actual ingress solution here.
A real ingress should usually be preffered, i.e. nginx or traefik, but we wanted to try this out and also this never has to scale.

It's a simple way to expose a Service outside the cluster without an external load balancer. Useful for development, testing, or bare-metal clusters without cloud load balancers.


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