#!/bin/bash

set -e

# Install K3s with Traefik enabled and flannel on the right interface
echo "[INFO] Installing K3s with Traefik..."
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--node-ip=192.168.56.110 --flannel-iface=enp0s8 --write-kubeconfig-mode 644" sh -

# Wait for k3s to be fully ready
echo "[INFO] Waiting for K3s server to be active..."
until systemctl is-active --quiet k3s; do
    sleep 2
done

# Export kubeconfig for current user
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Apply deployments and services
echo "[INFO] Deploying apps..."
kubectl apply -f /vagrant/confs/app1-deployment.yaml
kubectl apply -f /vagrant/confs/app2-deployment.yaml
kubectl apply -f /vagrant/confs/app3-deployment.yaml

# Apply ingress
echo "[INFO] Applying ingress rule..."
kubectl apply -f /vagrant/confs/ingress.yaml

echo "[INFO] Done! Apps should be reachable via Host headers."
