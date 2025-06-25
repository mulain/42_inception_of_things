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
  k3d cluster create mycluster --api-port 6550 \
    -p "8888:30080@server:0" \
    -p "8889:30081@server:0"
fi

# Handle 'argocd' namespace

if kubectl get namespace argocd &> /dev/null; then
  echo "✅ Argo CD namespace already exists."
else
  echo "=== Creating 'argocd' namespace ==="
  kubectl create namespace argocd
fi

# Handle Argo CD

if kubectl -n argocd get deploy argocd-server &> /dev/null; then
  echo "✅ Argo CD is already installed. Skipping installation."
else
  echo "=== Installing Argo CD ==="
  kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
fi

# Handle Argo CD CLI

if ! command -v argocd &> /dev/null; then
  echo "=== Installing Argo CD CLI ==="
  VERSION=$(curl -s https://api.github.com/repos/argoproj/argo-cd/releases/latest | grep tag_name | cut -d '"' -f 4)
  curl -sSL -o argocd "https://github.com/argoproj/argo-cd/releases/download/${VERSION}/argocd-linux-amd64"
  chmod +x argocd
  mv argocd /usr/local/bin/argocd
else
  echo "✅ Argo CD CLI already installed. Skipping..."
fi

# Readiness check

echo "📡 Waiting for Argo CD server deployment to be ready..."
kubectl rollout status deployment argocd-server -n argocd --timeout=120s
echo "✅ Argo CD server is ready."

# Forward port for ArgoCD server in background

kubectl -n argocd port-forward svc/argocd-server 8080:443 --address 0.0.0.0 > /dev/null 2>&1 &
sleep 5 # Wait for port forwarding to be established
echo "✅ Port forward started, PID: $!"

# Get Argo CD admin password

echo "🔑 Retrieving Argo CD admin password..."
until ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null); do
  echo "Waiting for Argo CD admin secret to be available..."
  sleep 5
done
echo "✅ Retrieved Argo CD admin password."

echo "🔐 Logging into Argo CD CLI..."
argocd login localhost:8080 --username admin --password "$ARGOCD_PASSWORD" --insecure

# Handle 'dev' namespace
kubectl get namespace dev &>/dev/null || kubectl create namespace dev

# Create and sync Argo CD application
echo "🚀 Creating and syncing Argo CD application 'wil-playground'..."
argocd app create wil-playground \
  --repo https://github.com/karolinakwasny/Inception_of_things_npavelic.git \
  --path p3/confs \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace dev \
  --sync-policy automated

argocd app sync wil-playground

echo "✅ Argo CD setup and app deployment complete!"
echo "password: $ARGOCD_PASSWORD"
