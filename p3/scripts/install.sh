#!/bin/bash

set -e

echo "=== Installing Docker ==="
curl -fsSL https://get.docker.com | bash
sudo usermod -aG docker $USER

echo "=== Installing k3d ==="
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

echo "=== Installing kubectl ==="
curl -LO "https://dl.k8s.io/release/$(curl -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/kubectl

echo "=== Creating K3d cluster ==="
k3d cluster create mycluster --api-port 6550 -p "8888:80@loadbalancer"

echo "=== Installing Argo CD ==="
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "=== Setup complete ==="
echo "To access Argo CD UI:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo
echo "Then visit: http://localhost:8080"
echo "Get admin password with:"
echo '  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d'
