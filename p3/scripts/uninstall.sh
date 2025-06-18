#!/bin/bash

set -e

echo "🧹 Starting cleanup of Argo CD setup and K3D cluster..."

### === Delete Argo CD Application === ###
if command -v argocd &> /dev/null; then
  echo "📦 Deleting Argo CD app 'wil-playground'..."
  argocd app delete wil-playground --yes || echo "⚠️ App not found or already deleted"
fi

### === Delete Kubernetes namespaces === ###
echo "🗑️ Deleting 'dev' namespace..."
kubectl delete namespace dev --ignore-not-found

echo "🗑️ Deleting 'argocd' namespace..."
kubectl delete namespace argocd --ignore-not-found

### === Delete K3D cluster === ###
if k3d cluster list | grep -q "^mycluster\s"; then
  echo "🧨 Deleting k3d cluster 'mycluster'..."
  k3d cluster delete mycluster
else
  echo "✅ No k3d cluster named 'mycluster' found."
fi

### === Optionally remove Argo CD CLI === ###
if command -v argocd &> /dev/null; then
  echo "🧽 Removing Argo CD CLI..."
  sudo rm -f /usr/local/bin/argocd
else
  echo "✅ Argo CD CLI not found. Skipping removal."
fi

### === (Optional) Remove kubectl and k3d binaries === ###
# echo "Removing kubectl and k3d (commented out for safety)..."
# sudo rm -f /usr/local/bin/kubectl
# sudo rm -f /usr/local/bin/k3d

echo "✅ Cleanup complete."
