#!/bin/bash

set -e

# Install Docker

if command -v docker &> /dev/null; then
  echo "✅ Docker is already installed. Skipping..."
else
  echo "=== Installing Docker ==="
  curl -fsSL https://get.docker.com | bash
  sudo usermod -aG docker $USER
  echo "Please log out and log back in to apply Docker group changes."
fi

# Install K3D

if command -v k3d &> /dev/null; then
  echo "✅ k3d is already installed. Skipping..."
else
  echo "=== Installing k3d ==="
  curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
fi

# Install kubectl

if command -v kubectl &> /dev/null; then
  echo "✅ kubectl is already installed. Skipping..."
else
  echo "=== Installing kubectl ==="
  KUBECTL_VERSION=$(curl -sL https://dl.k8s.io/release/stable.txt)
  echo "Latest kubectl version: $KUBECTL_VERSION"

  if [ -n "$KUBECTL_VERSION" ]; then
    curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/kubectl
    echo "✅ kubectl installed successfully!"
  else
    echo "❌ Failed to fetch latest kubectl version. Check your internet/DNS."
    exit 1
  fi
fi

# Create k3d cluster

if k3d cluster list | grep -q "^mycluster\s"; then
  echo "✅ Cluster 'mycluster' already exists. Skipping creation."
else
  k3d cluster create mycluster --api-port 6550 -p "8888:80@loadbalancer"
fi

# Ensure 'argocd' namespace exists and wait for it to be ready

if kubectl get namespace argocd &> /dev/null; then
  echo "✅ Argo CD namespace already exists."
else
  echo "=== Creating 'argocd' namespace ==="
  kubectl create namespace argocd
  echo "Waiting for 'argocd' namespace to be established..."
  kubectl wait --for=condition=Established namespace/argocd --timeout=90s
fi

echo "=== Installing Argo CD ==="
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# echo "=== Setup complete ==="
# echo "To access Argo CD UI in the machine running the cluster:"
# echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
# echo
# echo "Then visit: http://localhost:8080"
# echo "Get admin password with:"
# echo '  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d'
# echo "To access in the host machine running the vm that is running the cluster:"
# echo "ssh -L 8080:localhost:8080 user@192.168.56.110"

# added Argo CD setup

### === Install Argo CD CLI === ###
if ! command -v argocd &> /dev/null; then
  echo "=== Installing Argo CD CLI ==="
  VERSION=$(curl -s https://api.github.com/repos/argoproj/argo-cd/releases/latest | grep tag_name | cut -d '"' -f 4)
  curl -sSL -o argocd "https://github.com/argoproj/argo-cd/releases/download/${VERSION}/argocd-linux-amd64"
  chmod +x argocd
  sudo mv argocd /usr/local/bin/argocd
else
  echo "Argo CD CLI already installed. Skipping..."
fi

### === Port-forward Argo CD and Authenticate === ###
kubectl port-forward svc/argocd-server -n argocd 8080:443 > /dev/null 2>&1 &
sleep 5

ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)

echo "🔐 Logging into Argo CD CLI..."
argocd login localhost:8080 --username admin --password "$ARGOCD_PASSWORD" --insecure

### === Register the cluster with Argo CD === ###
# argocd cluster add k3d-mycluster --yes --insecure

kubectl get namespace dev &>/dev/null || kubectl create namespace dev

### === Create and Sync Argo CD App === ###
echo "🚀 Creating and syncing Argo CD application 'wil-playground'..."
argocd app create wil-playground \
  --repo https://github.com/karolinakwasny/Inception_of_things_npavelic.git \
  --path p3/confs \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace dev \
  --sync-policy automated

argocd app sync wil-playground

echo "✅ Argo CD setup and app deployment complete!"
echo "Use kubectl -n dev get svc,pods -o wide to check the status of the application and retrieve the service IP."
echo "External IP is the ip in the curl command in the next line; the port is what 8888:XXXX maps to."
echo "Use e.g. curl http://172.18.0.3:32191 to access the application from inside the vm."
